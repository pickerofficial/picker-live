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
        uint creatorReward;
    }

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
        uint[] amountPerOptions;
        uint accountEngagedAmount;
        uint accountEngagedIndex;
        bool engaged;
        bool claimed;
    }

    struct Creator {
        address account;
        uint count;
        uint fairnessUp;
        uint fairnessDown;
    }
}
