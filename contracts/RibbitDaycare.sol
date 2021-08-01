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

contract RibbitDaycare is IERC721Receiver {
    SURF surf;
    Ribbits ribbits;
    wRBT wrbt;
    // Price in SURF per day
    uint256 public daycareFee;
    // Hard limit to number of stakers
    uint256 public constant maxStakingSlots = 500;

    // Index => RibbitID
    uint256[] public ribbitIndex;
    // Index => Staker
    address[] public stakerIndex;
    // RibbitID => Owner
    mapping(uint256 => address) public ribbitOwners;
    // wRBT Staker => Amount
    mapping(address => uint256) public stakerBalances;
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

    /// @dev Gets the ID's of ribbits currently deposited by someone
    function GetDepositedRibbits(address owner)
        public
        view
        returns (uint256[] memory ribbitList)
    {
        uint256 counter = 0;
        for (uint256 index = 0; index < ribbitIndex.length; index++) {
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
    /// for half a Ribbit!
    function stakewRBT(uint256 amount) public {
        require(stakerIndex.length < maxStakingSlots, "No slots");
        require(amount % (1 * 10**18) == 0 && amount > 0, "Must be whole wRBT");
        require(
            amount <= wrbt.allowance(msg.sender, address(this)),
            "No allowance"
        );
        stakerBalances[msg.sender] += amount;
        if (!hasStakeIndex(msg.sender)) {
            stakerIndex.push(msg.sender);
        }
        wrbt.transferFrom(msg.sender, address(this), amount);
    }

    /// @dev Unstakes wRBT's in the contract if there is supply held and wraps abandoned ribbits if any.
    function unstakewRBT(uint256 amount) public {
        require(
            amount > 0 && stakerBalances[msg.sender] >= amount,
            "Not enough staked"
        );
        uint256 abandoned = getAbandonedRibbits().length;
        require(
            wrbtAvailable() + abandoned >= amount,
            "Not enough wRBT in contract"
        );
        require(amount % (1 * 10**18) == 0 && amount > 0, "Must be whole wRBT");
        if (abandoned > 0) {
            wrapAbandonedRibbits();
        }
        require(wrbtAvailable() >= amount);
        stakerBalances[msg.sender] -= amount;
        // Remove staker from the index
        if (stakerBalances[msg.sender] == 0) {
            for (uint256 index = 0; index < stakerIndex.length; index++) {
                if (stakerIndex[index] == msg.sender) {
                    // Swap the index with the last element and then pop()
                    if (index < stakerIndex.length && stakerIndex.length > 1) {
                        stakerIndex[index] = stakerIndex[
                            stakerIndex.length - 1
                        ];
                    }
                    stakerIndex.pop();
                    break;
                }
            }
        }
        wrbt.transfer(msg.sender, amount);
    }

    /// @dev Deposits a ribbit in exchange of a wRBT that is currently staked in the contract.
    /// @param _ribbitIds Array with the id's of the ribbits.
    /// @param _days Amount of days to deposit for, paid in SURF with bulk discount.
    function daycareDeposit(uint256[] memory _ribbitIds, uint256 _days) public {
        require(_days > 0, "Days can't be zero");
        uint256 ribbitNumber = _ribbitIds.length;
        uint256 abandonedRibbits = getAbandonedRibbits().length;
        uint256 surfAmount = _days * daycareFee;
        require(
            wrbtAvailable() / (1 * 10**18) + abandonedRibbits >= ribbitNumber,
            "Insufficient wRBT staked in contract"
        );
        require(
            surfAmount <= surf.allowance(msg.sender, address(this)),
            "Not enough SURF allowance"
        );
        // Wrap abandoned ribbits for liquidity, if any
        if (abandonedRibbits > 0) {
            wrapAbandonedRibbits();
        }
        // Add time and deposit date to each ribbit
        for (uint256 index = 0; index < ribbitNumber; index++) {
            ribbitDays[_ribbitIds[index]] = _days * 1 days;
            depositDates[_ribbitIds[index]] = block.timestamp;
            ribbitOwners[_ribbitIds[index]] = msg.sender;
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

        wrbt.transferFrom(msg.sender, address(this), amount * 10**18);
    }

    /// @dev Returns an array with all the abandoned ribbits.
    function getAbandonedRibbits()
        public
        view
        returns (uint256[] memory abandonedRibbits)
    {
        uint256 ribbitId;
        for (uint256 index = 0; index < ribbitIndex.length; index++) {
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
    /// @param _ribbitId The ID of the ribbit.
    /// @param amount The number of days to add to the ribbit.
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
        uint256 surfAmount = amount * daycareFee;
        distributeSURF(surfAmount);
        surf.transferFrom(msg.sender, address(this), surfAmount);
    }

    /// @dev Distributes SURF to staker balances
    /// @param amount The amount of SURF to be distributed
    function distributeSURF(uint256 amount) internal {
        require(amount > 0);
        amount = amount - (amount * surf.transferFee()) / 1000;
        uint256 dividend = amount / (getTotalStakes() / (1 * 10**18));
        for (uint256 index = 0; index < stakerIndex.length; index++) {
            address recipient = stakerIndex[index];
            uint256 dividends = dividend *
                (stakerBalances[recipient] / (1 * 10**18));
            surfBalances[recipient] += dividends;
        }
    }

    /// @dev Withdraws the SURF rewards of the sender
    function withdrawSURF() public {
        uint256 surfBalance = surf.balanceOf(address(this));
        require(
            surfBalance > 0 && surfBalances[msg.sender] > 0,
            "No SURF to withdraw"
        );
        uint256 amount = surfBalances[msg.sender];
        surfBalances[msg.sender] = 0;
        surf.transfer(msg.sender, amount);
    }

    /// @dev Returns the balance of wRBT held by the contract, rounded to a whole number
    function wrbtAvailable() public view returns (uint256) {
        return wrbt.balanceOf(address(this));
    }

    /// @dev Returns the total number of current stakes
    function getTotalStakes() public view returns (uint256 count) {
        for (uint256 index = 0; index < stakerIndex.length; index++) {
            count += stakerBalances[stakerIndex[index]];
        }
        return count;
    }

    /// @dev Checks whether the address is in the index
    function hasStakeIndex(address staker) internal view returns (bool) {
        for (uint256 index = 0; index < stakerIndex.length; index++) {
            if (stakerIndex[index] == staker) return true;
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
