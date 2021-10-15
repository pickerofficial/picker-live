// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "hardhat/console.sol";

import "./interfaces/IPriceCalculator.sol";

import {PickConstant} from "../library/PickConstant.sol";
import "../library/SafeToken.sol";

contract PickContract is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeBEP20 for IBEP20;
    using SafeMath for uint;
    using SafeToken for address;

    IPriceCalculator public constant priceCalculator = IPriceCalculator(0xE3B11c3Bd6d90CfeBBb4FB9d59486B0381D38021);

    uint public constant MAX_PERCENT = 10000;
    uint public constant CREATOR_PERCENT = 300;
    uint public constant ACCOUNT_PERCENT = 9400;

    uint public constant OPTION_LIMIT = 2;

    uint public pickCount;

    /* ========== STATE VARIABLES ========== */
    mapping(uint => PickConstant.Pick) public picks;
    mapping(address => PickConstant.Creator) public creators;

    mapping(address => uint[]) public accountHistories;
    mapping(uint => mapping(address => bool)) private accountEngages;
    mapping(uint => mapping(address => bool)) private accountClaimed;

    mapping(uint => mapping(uint => uint)) public balancePerOption;
    mapping(uint => mapping(uint => mapping(address => uint))) public accountBalancePerOption;

    /* ========== MODIFIERS ========== */
    modifier onlyValidateOption(uint id, uint result) {
        require(picks[id].options.length > result, 'invalid option');
        _;
    }

    /* ========== EVENTS ========== */
    event PickCreated (address indexed account, uint id);
    event PickEngaged (address indexed account, uint id, uint amount);
    event PickFinished (uint id, uint result);
    event PickCanceled (uint id);
    event RewardClaimed (address indexed account, uint id, uint amount);

    /* ========== INITIALIZER ========== */
    function initialize() external initializer {
        __Ownable_init();
    }

    /* ========== Main FUNCTIONS ========== */
    function create(string memory title, string[] memory options, uint deadline) external {
        require(block.timestamp < deadline, 'invalid deadline');
        require(OPTION_LIMIT >= options.length, 'too many option');

        picks[pickCount].title = title;
        picks[pickCount].deadline = deadline;
        picks[pickCount].creator = msg.sender;
        picks[pickCount].result = uint(- 1);

        for (uint i = 0; i < options.length; i++) {
            picks[pickCount].options.push(options[i]);
        }

        creators[msg.sender].count++;
        creators[msg.sender].account = msg.sender;
        emit PickCreated(msg.sender, pickCount++);
    }

    function finish(uint id, uint result) external nonReentrant onlyValidateOption(id, result) {
        require(block.timestamp >= picks[id].deadline, "not pick before deadline");
        require(picks[id].creator == msg.sender, 'no creator');
        require(!picks[id].closed, 'already finish');
        require(!picks[id].canceled, 'already revoked');
        require(!accountClaimed[id][picks[id].creator], 'already claimed');

        picks[id].result = result;
        picks[id].closed = true;

        // TODO handle cases (draw, invalid division - 99% : 1%)

        picks[id].creatorReward = (picks[id].totalAmount.mul(CREATOR_PERCENT)).div(MAX_PERCENT);
        accountClaimed[id][picks[id].creator] = true;
        SafeToken.safeTransferETH(picks[id].creator, picks[id].creatorReward);

        emit PickFinished(id, result);
        //        TODO
        //        uint loserAmount;
        //        for (uint i = 0; i < picks[id].options.length; i++) {
        //            if (result == i) {
        //                continue;
        //            } else {
        //                loserAmount += balancePerOption[id][i];
        //            }
        //        }
        //        picks[id].totalAmount = picks[id].totalAmount - loserAmount.div(100).mul(30);
        //        console.log(loserAmount.div(100).mul(30));
        //                uint reserve = loserAmount.div(10);
        //                uint govVault = loserAmount.div(10);
        //                uint govMaticValut = loserAmount.div(10);
    }

    function cancel (uint id) external {
        require(block.timestamp >= picks[id].deadline, "not pick before deadline");
        require(picks[id].creator == msg.sender, 'no creator');
        require(!picks[id].closed, 'already finish');
        require(!picks[id].canceled, 'already revoked');

        picks[id].closed = true;
        picks[id].canceled = true;

        emit PickCanceled(id);
    }

    function engage(uint id, uint select) external payable onlyValidateOption(id, select) {
        require(picks[id].creator != msg.sender, "Creator can't vote");
        require(!accountEngages[id][msg.sender], 'you already picked');
        require(now < picks[id].deadline, 'voting time is done');

        picks[id].totalAmount = picks[id].totalAmount.add(msg.value);
        picks[id].totalPickCount++;
        balancePerOption[id][select] = balancePerOption[id][select].add(msg.value);
        accountBalancePerOption[id][select][msg.sender] = msg.value;
        accountHistories[msg.sender].push(id);
        accountEngages[id][msg.sender] = true;

        emit PickEngaged(msg.sender, id, msg.value);
    }

    function claim(uint id, uint result, bool isFair) external nonReentrant {
        require(picks[id].closed, 'pick not finish');
        require(!accountClaimed[id][msg.sender], 'already claimed');
        require(picks[id].creator == msg.sender || accountEngages[id][msg.sender], 'your are not engaged');

        if (isFair) {
            creators[picks[id].creator].fairnessUp++;
        } else {
            creators[picks[id].creator].fairnessDown++;
        }

        uint reward = rewardOf(msg.sender, id);

        accountClaimed[id][msg.sender] = true;
        SafeToken.safeTransferETH(msg.sender, reward);

        emit RewardClaimed(msg.sender, id, reward);
    }

    /* ========== View Functions ========== */
    function creatorOf(address account) public view returns (PickConstant.Creator memory){
        return creators[account];
    }

    function rewardOf(address account, uint id) public view returns (uint reward) {
        bool isCorrector = false;
        uint result = 0;
        for (uint i = 0; i < picks[i].options.length; i++) {
            if (accountBalancePerOption[id][i][account] > 0) {
                result = i;
                break;
            }
        }
        isCorrector = result == picks[id].result;

        if(picks[id].canceled){
            reward = accountBalancePerOption[id][result][account];
        }else{
            if (isCorrector) {
                reward = (picks[id].totalAmount.mul(ACCOUNT_PERCENT)).div(MAX_PERCENT);
                reward = (reward.mul(accountBalancePerOption[id][result][account])).div(balancePerOption[id][result]);
            } else {
                reward = 0;
            }
        }
    }

    function expectedRewardOf(address account, uint id, uint result) public view returns (uint reward){
        if (account == picks[id].creator) {
            reward = (picks[id].totalAmount.mul(CREATOR_PERCENT)).div(MAX_PERCENT);
        } else {
            reward = (picks[id].totalAmount.mul(ACCOUNT_PERCENT)).div(MAX_PERCENT);
            reward = (reward.mul(accountBalancePerOption[id][result][account])).div(balancePerOption[id][result]);
        }
    }

    function balanceOf(uint id) public view returns (uint){
        return picks[id].totalAmount;
    }

    function optionBalanceOf(uint id, uint result) public view returns (uint) {
        return balancePerOption[id][result];
    }

    function accountOptionBalanceOf(address account, uint id, uint result) public view returns (uint){
        return accountBalancePerOption[id][result][account];
    }

    function pickOf(address account, uint id) public view returns (PickConstant.PickReturnType memory pickReturn) {
        pickReturn.title = picks[id].title;
        pickReturn.creator = picks[id].creator;
        pickReturn.closed = picks[id].closed;
        pickReturn.canceled = picks[id].canceled;
        pickReturn.pickId = id;
        pickReturn.deadline = picks[id].deadline;
        pickReturn.totalAmount = picks[id].totalAmount;
        pickReturn.totalPickCount = picks[id].totalPickCount;
        pickReturn.options = picks[id].options;
        pickReturn.result = picks[id].result;
        pickReturn.creatorReward = picks[id].creatorReward;
        if(account != address(0)){
            pickReturn.claimed = accountClaimed[id][account];
        }
        pickReturn.amountPerOptions = new uint[](picks[id].options.length);
        pickReturn.accountEngagedIndex = uint(- 1);

        for (uint i = 0; i < picks[id].options.length; i++) {
            pickReturn.amountPerOptions[i] = balancePerOption[id][i];

            if (accountBalancePerOption[id][i][account] > 0 && account != address(0)) {
                pickReturn.accountEngagedAmount = accountBalancePerOption[id][i][account];
                pickReturn.accountEngagedIndex = i;
                pickReturn.engaged = true;
            }
        }
    }

    function pickList(uint page, uint resultPerPage) public view returns (PickConstant.PickReturnType[] memory pickReturns) {
        uint start = pickCount.sub(page.mul(resultPerPage)).sub(1);
        uint end = 0;
        if (page.add(1).mul(resultPerPage) <= pickCount) {
             end = pickCount.sub(page.add(1).mul(resultPerPage));
        }
        uint returnSize = start.sub(end).add(1);

        pickReturns = new PickConstant.PickReturnType[](returnSize);
        uint lengthIndex = 0;

        for (start; start >= end; start--) {
            pickReturns[lengthIndex].title = picks[start].title;
            pickReturns[lengthIndex].creator = picks[start].creator;
            pickReturns[lengthIndex].closed = picks[start].closed;
            pickReturns[lengthIndex].canceled = picks[start].canceled;
            pickReturns[lengthIndex].pickId = start;
            pickReturns[lengthIndex].deadline = picks[start].deadline;
            pickReturns[lengthIndex].totalAmount = picks[start].totalAmount;
            pickReturns[lengthIndex].totalPickCount = picks[start].totalPickCount;
            pickReturns[lengthIndex].options = picks[start].options;
            pickReturns[lengthIndex].result = picks[start].result;
            pickReturns[lengthIndex].creatorReward = picks[start].creatorReward;
            if(msg.sender != address(0)){
                pickReturns[lengthIndex].claimed = accountClaimed[start][msg.sender];
            }
            pickReturns[lengthIndex].amountPerOptions = new uint[](picks[start].options.length);

            for (uint j = 0; j < picks[start].options.length; j++) {
                pickReturns[lengthIndex].amountPerOptions[j] = balancePerOption[start][j];

                if (accountBalancePerOption[start][j][msg.sender] > 0 && msg.sender != address(0)) {
                    pickReturns[lengthIndex].engaged = true;
                    pickReturns[lengthIndex].accountEngagedIndex = j;
                }
            }
            lengthIndex++;
            if(start==0)break;
        }
    }

    function historyOf(address account, uint page, uint resultPerPage) public view returns (PickConstant.PickReturnType[] memory pickReturns) {
        uint start = pickCount.sub(page.mul(resultPerPage)).sub(1);
        uint end = 0;
        if (page.add(1).mul(resultPerPage) <= pickCount) {
            end = pickCount.sub(page.add(1).mul(resultPerPage));
        }
        uint returnSize = start.sub(end).add(1);

        pickReturns = new PickConstant.PickReturnType[](returnSize);
        uint lengthIndex = 0;

        for (start; start >= end; start--) {
            pickReturns[lengthIndex].title = picks[accountHistories[account][start]].title;
            pickReturns[lengthIndex].creator = picks[accountHistories[account][start]].creator;
            pickReturns[lengthIndex].closed = picks[accountHistories[account][start]].closed;
            pickReturns[lengthIndex].deadline = picks[accountHistories[account][start]].deadline;
            pickReturns[lengthIndex].totalAmount = picks[accountHistories[account][start]].totalAmount;
            pickReturns[lengthIndex].options = picks[accountHistories[account][start]].options;
            pickReturns[lengthIndex].result = picks[accountHistories[account][start]].result;
            pickReturns[lengthIndex].creatorReward = picks[accountHistories[account][start]].creatorReward;
            pickReturns[lengthIndex].amountPerOptions = new uint[](picks[accountHistories[account][start]].options.length);

            for (uint j = 0; j < picks[accountHistories[account][start]].options.length; j++) {
                pickReturns[lengthIndex].amountPerOptions[j] = balancePerOption[start][j];
            }
            lengthIndex++;
            if(start==0)break;
        }
    }
}
