// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;
contract Purchase {
    uint public value;
    address payable public seller;
    address payable public buyer;
    uint256 private timePurchaseConfirmed;

    enum State { Created, Locked, Inactive }
    // The state variable has a default value of the first member, `State.created`
    State public state;

    modifier condition(bool condition_) {
        require(condition_);
        _;
    }

    /// Only the seller can call this function.
    error OnlySeller();
    /// The function cannot be called at the current state.
    error InvalidState();
    /// The provided value has to be even.
    error ValueNotEven();
    /// cannot complete purchase at the current state
    error CanCompletePurchase();

    modifier onlySeller() {
        if (msg.sender != seller)
            revert OnlySeller();
        _;
    }

    /// can only complete purchase if caller is the buyer or
    /// >= 5 minutes have elapsed since the buyer called confirmPurchase
    modifier canCompletePurchase() {
        if (!(msg.sender == buyer || 
            // make sure the purchase is actually confirmed
            (timePurchaseConfirmed != 0 && 
            // confirmed more than 5 minutes ago
            block.timestamp - timePurchaseConfirmed >= 300)))
            revert CanCompletePurchase();
        _;
    }

    modifier inState(State state_) {
        if (state != state_)
            revert InvalidState();
        _;
    }

    event Aborted();
    event PurchaseConfirmed();
    event PurchaseCompleted();

    // Ensure that `msg.value` is an even number.
    // Division will truncate if it is an odd number.
    // Check via multiplication that it wasn't an odd number.
    constructor() payable {
        seller = payable(msg.sender);
        value = msg.value / 2;
        if ((2 * value) != msg.value)
            revert ValueNotEven();
    }

    /// Abort the purchase and reclaim the ether.
    /// Can only be called by the seller before
    /// the contract is locked.
    function abort()
        external
        onlySeller
        inState(State.Created)
    {
        emit Aborted();
        state = State.Inactive;
        // We use transfer here directly. It is
        // reentrancy-safe, because it is the
        // last call in this function and we
        // already changed the state.
        seller.transfer(address(this).balance);
    }

    /// Confirm the purchase as buyer.
    /// Transaction has to include `2 * value` ether.
    /// The ether will be locked until confirmReceived
    /// is called.
    function confirmPurchase()
        external
        inState(State.Created)
        condition(msg.value == (2 * value))
        payable
    {
        emit PurchaseConfirmed();
        buyer = payable(msg.sender);
        state = State.Locked;
        // record the time the purchase is confirmed
        timePurchaseConfirmed = block.timestamp;
    }

    /// Confirm that you (the buyer) received the item.
    /// Then refund the seller and set the stage of the contract 
    /// to be inactive
    function completePurchase()
        external
        inState(State.Locked)
        canCompletePurchase
    {
        emit PurchaseCompleted();
        state = State.Inactive;
        buyer.transfer(value);
        seller.transfer(3 * value);

        // Reset value of timePurchaseConfirmed to 0 to indicate 
        // that transaction is complete
        timePurchaseConfirmed = 0;
    }
}