//SPDX-License-Identifier: MIT
//  ___   ___      ______       __
// /__/\ /__/\    /_____/\     /_/\
// \::\ \\  \ \   \:::_ \ \    \:\ \
//  \::\/_\ .\ \   \:\ \ \ \    \:\ \
//   \:: ___::\ \   \:\ \ \ \    \:\ \____
//    \: \ \\::\ \   \:\_\ \ \    \:\/___/\
//     \__\/ \::\/    \_____\/     \_____\/
/// @title Ribbit Daycare
/// @author Hol
/// @notice A wrapper for Ribbits with ownership.

pragma solidity ^0.8.4;

import "./Interfaces.sol";

contract RibbitDaycare is IERC721Receiver {
    SURF surf;
    Ribbits ribbits;
    wRBT wrbt;
    // Price in SURF per day
    uint256 public daycareFee;
    // Hard limit to number of stakers
    uint256 public constant maxStakingSlots = 500;
    // Current Stakes
    uint256 public currentStakes;
    uint256 public surfRewards;
    // wRBT Staker => Amount
    mapping(address => uint256) public stakerBalances;
    // Snapshots to calculate the reward
    mapping(address => uint256) rewardSnapshots;

    // Index => RibbitID
    uint256[] public ribbitIndex;
    // Index => Staker
    address[] public stakerIndex;
    // RibbitID => Owner
    mapping(uint256 => address) public ribbitOwners;

    // RibbitID => Number of Days
    mapping(uint256 => uint256) public ribbitDays;
    // RibbitID => Depositted Timestamp
    mapping(uint256 => uint256) public depositDates;
    // address => SURF Balance
    mapping(address => uint256) public surfBalances;

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

    /// @dev Gets the ID's of ribbits currently deposited by someone.
    /// @param owner The address of the owner.
    /// @return ribbitList List of ribbits owned by the address.
    function GetDepositedRibbits(address owner)
        external
        view
        returns (uint256[] memory ribbitList)
    {
        uint256 counter = 0;
        for (uint256 index = 0; index < ribbitIndex.length; index++) {
            if (ribbitOwners[ribbitIndex[index]] == owner) {
                counter++;
            }
        }
        ribbitList = new uint256[](counter);
        counter = 0;
        for (uint256 index = 0; index < ribbitIndex.length; index++) {
            if (ribbitOwners[ribbitIndex[index]] == owner) {
                ribbitList[counter] = ribbitIndex[index];
                counter++;
            }
        }
        return ribbitList;
    }

    /// @dev Stakes wRBT's in the contract.
    /// @param amount The amount of wRBT staked, whole number.
    /// Sticking to whole numbers for simplicity, as staking 0.5 wRBT
    /// that is currently not in contract is impossible to withdraw
    /// for half a Ribbit!
    function stakewRBT(uint256 amount) public {
        require(amount % (1 * 10**18) == 0 && amount > 0, "Must be whole wRBT");
        stakerBalances[msg.sender] += amount;
        rewardSnapshots[msg.sender] = surfRewards;
        currentStakes += amount;
        wrbt.transferFrom(msg.sender, address(this), amount);
    }

    /// @dev Unstakes wRBT's in the contract if there is supply held.
    function unstakewRBT(uint256 amount) public {
        require(
            amount > 0 && stakerBalances[msg.sender] >= amount,
            "Not enough staked"
        );
        require(wrbtAvailable() >= amount, "Not enough wRBT in contract");
        require(amount % (1 * 10**18) == 0 && amount > 0, "Must be whole wRBT");
        withdrawSURF();
        stakerBalances[msg.sender] -= amount;
        currentStakes -= amount;
        wrbt.transfer(msg.sender, amount);
    }

    /// @dev Withdraws the SURF rewards of the sender and changes snapshot
    function withdrawSURF() public {
        uint256 surfBalance = surf.balanceOf(address(this));
        uint256 unclaimedSurf = stakerBalances[msg.sender] *
            (surfRewards - rewardSnapshots[msg.sender]);
        if (surfBalance > 0 && unclaimedSurf > 0) {
            rewardSnapshots[msg.sender] = surfRewards;
            surf.transfer(msg.sender, unclaimedSurf);
        }
    }

    /// @dev Deposits a ribbit in exchange of a wRBT that is currently staked in the contract.
    /// @param _ribbitIds Array with the id's of the ribbits.
    /// @param _days Amount of days to deposit for, paid in SURF with bulk discount.
    function daycareDeposit(uint256[] memory _ribbitIds, uint256 _days) public {
        require(_days > 0, "Days can't be zero");
        uint256 ribbitNumber = _ribbitIds.length;
        uint256 surfAmount = _days * daycareFee;
        require(
            wrbtAvailable() / (1 * 10**18) >= ribbitNumber,
            "Insufficient wRBT staked in contract"
        );
        // Add time and deposit date to each ribbit
        for (uint256 index = 0; index < ribbitNumber; index++) {
            uint256 ribId = _ribbitIds[index];
            ribbitDays[ribId] = _days * 1 days;
            depositDates[ribId] = block.timestamp;
            ribbitOwners[ribId] = msg.sender;
            if (!hasRibbitIndex(ribId)) {
                ribbitIndex.push(ribId);
            }
        }
        // Transfer each ribbit
        for (uint256 index = 0; index < ribbitNumber; index++) {
            ribbits.safeTransferFrom(
                msg.sender,
                address(this),
                _ribbitIds[index]
            );
        }

        distributeSURF(surfAmount);
        surf.transferFrom(msg.sender, address(this), surfAmount);
        wrbt.transfer(msg.sender, ribbitNumber * 10**18);
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

    /// @dev Withdraws ribbits by their owner in exchange of a wRBT
    /// @param _ribbitIds Array with the ids of all the Ribbits
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

        wrbt.transferFrom(msg.sender, address(this), amount * 10**18);
    }

    /// @dev Returns an array with all the abandoned ribbits.
    function getAbandonedRibbits()
        public
        view
        returns (uint256[] memory abandonedRibbits)
    {
        uint256 ribbitId;
        uint256 count;
        for (uint256 index = 0; index < ribbitIndex.length; index++) {
            ribbitId = ribbitIndex[index];
            if (isAbandoned(ribbitId)) {
                count++;
            }
        }
        abandonedRibbits = new uint256[](count);
        count = 0;
        for (uint256 index = 0; index < ribbitIndex.length; index++) {
            ribbitId = ribbitIndex[index];
            if (isAbandoned(ribbitId)) {
                abandonedRibbits[count] = ribbitId;
            }
        }
        return abandonedRibbits;
    }

    /// @dev Calculates whether a deposited ribbit is out of time.
    /// @param _ribbitId The id of the ribbit.
    function isAbandoned(uint256 _ribbitId) public view returns (bool) {
        return
            depositDates[_ribbitId] + ribbitDays[_ribbitId] < block.timestamp &&
            ribbits.ownerOf(_ribbitId) == address(this);
    }

    /// @dev Adds day credits to the ribbit specified, must be already deposited
    /// @param _ribbitId The ID of the ribbit.
    /// @param amount The number of days to add to the ribbit.
    function addDays(uint256 _ribbitId, uint256 amount) public {
        require(
            ribbits.ownerOf(_ribbitId) == address(this),
            "Ribbit not in daycare"
        );
        ribbitDays[_ribbitId] += amount * 1 days;
        uint256 surfAmount = amount * daycareFee;
        distributeSURF(surfAmount);
        surf.transferFrom(msg.sender, address(this), surfAmount);
    }

    /// @dev Adds the calculated surf reward dividend for the current snapshot
    /// @param amount The amount of SURF to be distributed
    function distributeSURF(uint256 amount) internal {
        require(amount > 0 && currentStakes > 0);
        amount = amount - (amount * surf.transferFee()) / 1000;
        surfRewards += amount / currentStakes;
    }

    /// @dev Returns the balance of wRBT held by the contract, rounded to a whole number
    function wrbtAvailable() public view returns (uint256) {
        return wrbt.balanceOf(address(this));
    }

    /// @dev Checks whether the ribbit is in the index
    function hasRibbitIndex(uint256 _ribbitId) internal view returns (bool) {
        for (uint256 index = 0; index < ribbitIndex.length; index++) {
            if (ribbitIndex[index] == _ribbitId) return true;
        }
        return false;
    }

    /// @dev Needed to deposit ribbits?
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        if (this.onERC721Received.selector != 0x150b7a02) {
            return 0x150b7a02;
        }
        return this.onERC721Received.selector;
    }
}
