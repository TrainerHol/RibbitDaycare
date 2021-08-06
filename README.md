# Ribbit Daycare

Ribbit Daycare is a wrapping system designed for keeping your rare [ribbits](https://ribbits.xyz) safe by allowing you to deposit your ribbit in the contract for a set amount of time.

The contract gets its wRBT supply from stakers and these are rewarded with the [SURF](https://surf.finance) fee paid for depositing a ribbit. 

### Using the Daycare

To deposit your ribbits in the contract, you need to set an allowance for this contract for both your Ribbits that you will deposit and the SURF that will be used for the fee. 

When depositing ribbits, the contract will give you the same amount of wRBT as the number of ribbits deposited and only the address that deposits the ribbit can withdraw them from the contract. 

When withdrawing ribbits, an equal amount of wRBT must be supplied in exchange.

### Depositing Fees

The daycare fee is paid in x amount of SURF when depositing ribbits. Multiple ribbits can be deposited at once with the same transaction, as long as there's enough wRBT supply in the contract to cover for all of them. This makes it a lot cheaper if you own multiple ribbits. 

The SURF fee is then distributed to all the wRBT stakers, proportional to the amount of wRBT staked at the time of deposit. You can call the [withdrawSURF](https://github.com/TrainerHol/RibbitDaycare/blob/aca602440cdff6abc31cb285f22d6b0e324b6313/contracts/RibbitDaycare.sol#L248) function to claim your staking rewards.

Stakers can unstake as long as there's wRBT supply in the contract or until a ribbit is abandoned. 

### Abandoned Ribbits

In order to keep the supply of wRBT in the contract, ribbits that haven't been withdrawn by the time paid for will be marked as abandoned. 

The [wrapAbandonedRibbits](https://github.com/TrainerHol/RibbitDaycare/blob/aca602440cdff6abc31cb285f22d6b0e324b6313/contracts/RibbitDaycare.sol#L156) function can be called by anyone to have the contract call the main wrapped ribbit contract and exchange the abandoned ribbits for wRBT. 

The [getAbandonedRibbits](https://github.com/TrainerHol/RibbitDaycare/blob/aca602440cdff6abc31cb285f22d6b0e324b6313/contracts/RibbitDaycare.sol#L188) view can be used to get a list of the current ribbits marked as abandoned.
