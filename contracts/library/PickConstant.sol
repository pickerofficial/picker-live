// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

library PickConstant {
    struct Pick {
        address creator;
        bool closed;
        bool canceled;
        string title;
        string[] options;
        uint deadline;
        uint totalAmount;
        uint totalPickCount;
        uint result;
        uint creatorReward;//contract의 static으로 사용
    }

    //Pick에 사용되는 필드를 중복해도 된다 > interface에서 편하기위해
    struct PickReturnType {
        address creator;
        bool closed;
        bool canceled;
        string title;
        string[] options;
        uint deadline;
        uint totalAmount;
        uint totalPickCount;
        uint result;
        uint creatorReward;

        uint pickId;
        uint[] amountPerOptions; //문제에서 option별 모인 총 금액
        uint accountEngagedAmount; //pickOf시 사용
        uint accountEngagedIndex; //pickOf시 사용
        bool engaged;
        bool claimed;
    }

    struct Creator {
        address account;
        uint count;
        uint fairnessUp;//고민
        uint fairnessDown;
    }
}
