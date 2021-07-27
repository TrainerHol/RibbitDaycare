//SPDX-License-Identifier: MIT
//  ___   ___      ______       __
// /__/\ /__/\    /_____/\     /_/\
// \::\ \\  \ \   \:::_ \ \    \:\ \
//  \::\/_\ .\ \   \:\ \ \ \    \:\ \
//   \:: ___::\ \   \:\ \ \ \    \:\ \____
//    \: \ \\::\ \   \:\_\ \ \    \:\/___/\
//     \__\/ \::\/    \_____\/     \_____\/
pragma solidity ^0.8.4;

import "./Interfaces.sol";

contract RibbitDaycare {
    SURF surf;
    Ribbits ribbits;
    wRBT wrbt;
    uint256 public ribbitCount;
    uint256 public wRBTCount;
    // Price in SURF per day
    uint256 public daycareFee;

    // Index => RibbitID
    mapping(uint256 => uint256) public ribbitIndex;
    // RibbitID => Owner
    mapping(uint256 => address) public ribbitOwners;
    // wRBT Staker => Amount
    mapping(address => uint256) public stakerBalances;
    // RibbitID => Number of Days
    mapping(uint256 => uint256) public ribbitDays;
    // RibbitID => Depositted Timestamp
    mapping(uint256 => uint256) public depositDates;

    constructor(
        address _surf,
        address _ribbits,
        address _wrbt,
        uint256 _daycareFee
    ) {
        surf = SURF(_surf);
        ribbits = Ribbits(_ribbits);
        wrbt = wRBT(_wrbt);
        daycareFee = _daycareFee;
        ribbits.setApprovalForAll(_wrbt, true);
    }

    /// @dev Gets the ID's of ribbits currently deposited by someone
    function GetDepositedRibbits(address owner)
        public
        view
        returns (uint256[] memory ribbitList)
    {
        uint256 counter = 0;
        for (uint256 index = 0; index < ribbitCount; index++) {
            if (ribbitOwners[ribbitIndex[index]] == owner) {
                ribbitList[counter] = (ribbitIndex[index]);
                counter++;
            }
        }
        return ribbitList;
    }

    /// @dev Stakes wRBT's in the contract.
    /// @param amount The amount of wRBT staked, whole number.
    /// Sticking to whole numbers for simplicity, as staking 0.5 wRBT
    /// that is currently not in contract is impossible to withdraw
    /// for 0.5 Ribbits!
    function stakewRBT(uint256 amount) public {
        require(amount % (1 * 10**18) == 0, "Must be whole wRBT");
        require(
            amount <= wrbt.allowance(msg.sender, address(this)),
            "No allowance"
        );
        stakerBalances[msg.sender] += amount;
        wrbt.transferFrom(msg.sender, address(this), amount);
    }

    /// @dev Unstakes wRBT's in the contract if there is supply held.
    function unstakewRBT(uint256 amount) public {
        //TODO: Unstake wRBT only if the contract holds abandonded ribbits (and wrap them) or wRBT
    }

    /// @dev Deposits a ribbit in exchange of a wRBT that is currently staked.
    /// @param _ribbitIds Array with the id's of the ribbits.
    /// @param _days Amount of days to deposit for, paid in SURF with bulk discount.
    function daycareDeposit(uint256[] memory _ribbitIds, uint256 _days) public {
        uint256 ribbitNumber = _ribbitIds.length;
        require(
            wrbtAvailable() >= ribbitNumber,
            "Insufficient wRBT staked in contract"
        );
        require(
            _days <= surf.allowance(msg.sender, address(this)),
            "Not enough SURF allowance"
        );
        // Add time and deposit date to each ribbit
        for (uint256 index = 0; index < ribbitNumber; index++) {
            ribbitDays[_ribbitIds[index]] = _days * 1 days;
            depositDates[_ribbitIds[index]] = block.timestamp;
        }
        // Transfer each ribbit
        for (uint256 index = 0; index < ribbitNumber; index++) {
            ribbits.safeTransferFrom(
                msg.sender,
                address(this),
                _ribbitIds[index]
            );
        }
        surf.transferFrom(msg.sender, address(this), _days * daycareFee);
        wrbt.transfer(msg.sender, ribbitNumber);
    }

    /// @dev Wraps all ribbits owned by the contract that have no time left.
    function wrapAbandonedRibbits() public {
        //TODO: Bulk wrap all the ribbits with no time left, remove from lists, etc.
        uint256[] memory abandonedRibbits = getAbandonedRibbits();
        require(abandonedRibbits.length > 0, "No abandonded ribbits");
        for (uint256 index = 0; index < abandonedRibbits.length; index++) {
            delete ribbitOwners[abandonedRibbits[index]];
            delete depositDates[abandonedRibbits[index]];
            delete ribbitDays[abandonedRibbits[index]];
        }
        wrbt.wrap(abandonedRibbits);
    }

    /// @dev Withdraws ribbits by owner in exchange of a wRBT
    function withdrawRibbits(uint256[] memory _ribbitIds) public {
        uint256 amount = _ribbitIds.length;
        for (uint256 index = 0; index < amount; index++) {
            uint256 _ribbitId = _ribbitIds[index];
            require(
                ribbits.ownerOf(_ribbitId) == address(this),
                "Ribbit not in contract"
            );
            require(ribbitOwners[_ribbitId] == msg.sender, "Not ribbit owner");
            delete ribbitOwners[_ribbitId];
            delete depositDates[_ribbitId];
            delete ribbitDays[_ribbitId];
            ribbits.safeTransferFrom(address(this), msg.sender, _ribbitId);
        }

        wrbt.transferFrom(msg.sender, address(this), amount);
    }

    /// @dev Returns an array with all the abandoned ribbits.
    function getAbandonedRibbits()
        public
        view
        returns (uint256[] memory abandonedRibbits)
    {
        uint256 ribbitId;
        for (uint256 index = 0; index < ribbitCount; index++) {
            ribbitId = ribbitIndex[index];
            if (isAbandoned(ribbitId)) {
                abandonedRibbits[index] = ribbitId;
            }
        }
        return abandonedRibbits;
    }

    /// @dev Calculates whether a deposited ribbit is out of time.
    function isAbandoned(uint256 _ribbitId) public view returns (bool) {
        return
            depositDates[_ribbitId] + ribbitDays[_ribbitId] < block.timestamp &&
            ribbits.ownerOf(_ribbitId) == address(this);
    }

    /// @dev Adds day credits to the ribbit specified, must be already deposited
    function addDays(uint256 _ribbitId, uint256 amount) public {
        require(
            ribbits.ownerOf(_ribbitId) == address(this),
            "Ribbit not in daycare"
        );
        require(
            amount <= surf.allowance(msg.sender, address(this)),
            "Not enough SURF allowance"
        );
        ribbitDays[_ribbitId] += amount * 1 days;
        surf.transferFrom(msg.sender, address(this), amount);
    }

    /// @dev Returns the balance of wRBT held by the contract, rounded to a whole number
    function wrbtAvailable() public view returns (uint256) {
        return wrbt.balanceOf(address(this)) / (1 * 10**18);
    }
}
