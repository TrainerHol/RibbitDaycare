//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Interfaces.sol";

contract RibbitDaycare {
    SURF surf;
    Ribbits ribbits;
    wRBT wrbt;
    uint256 public ribbitCount;
    // Price in SURF per day
    uint256 public daycareFee;

    // Index => RibbitID
    mapping(uint256 => uint256) public ribbitIndex;
    // RibbitID => Owners
    mapping(uint256 => address) public ribbitOwners;
    // wRBT Staker => Amount
    mapping(address => uint256) public stakerBalances;
    // RibbitID => Number of Days
    mapping(uint256 => uint256) public ribbitDays;

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

    function daycareWrap(uint256[] memory _ribbitIds, uint256[] memory _days)
        public
    {
        require(
            wrbtAvailable() >= _ribbitIds.length,
            "Insufficient wRBT staked in contract"
        );
        require(_ribbitIds.length == _days.length, "Incomplete day data");
        uint256 dayCount;
        for (uint256 index = 0; index < _days.length; index++) {
            dayCount += _days[index];
        }
        require(
            dayCount <= surf.allowance(msg.sender, address(this)),
            "Not enough SURF allowance"
        );
        for (uint256 index = 0; index < _ribbitIds.length; index++) {
            ribbitDays[_ribbitIds[index]] = _days[index] * 1 days;
        }
        for (uint256 index = 0; index < _ribbitIds.length; index++) {
            ribbits.safeTransferFrom(
                msg.sender,
                address(this),
                _ribbitIds[index]
            );
        }
        surf.transferFrom(msg.sender, address(this), dayCount * daycareFee);
    }

    /// @dev Adds day credits to the ribbit specified
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

    function wrbtAvailable() public view returns (uint256) {
        return wrbt.balanceOf(address(this));
    }
}
