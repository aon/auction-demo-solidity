//SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.9.0;

contract AuctionCreator {
    Auction[] public auctions;
    
    function createAuction() public {
        Auction newAuction = new Auction(msg.sender);
        auctions.push(newAuction);
    }
    
}

contract Auction {
    address payable public owner;
    uint public startBlock;
    uint public endBlock;
    string public ipfsHash;
    
    enum State {Started, Running, Ended, Cancelled}
    State public auctionState;
    
    uint public highestBindingBid;
    address payable public highestBidder;
    
    mapping(address => uint) public bids;
    uint bidIncrement;
    
    constructor(address eoa) {
        owner = payable(eoa);
        auctionState = State.Running;
        startBlock = block.number;
        endBlock = startBlock + 40320;  // One block per 15s, so 40320 blocks = 1 weeks
        ipfsHash = "";
        bidIncrement = 100;
    }
    
    modifier notOwner() {
        require(msg.sender != owner, "Owner is not allowed to do this action");
        _;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    modifier afterStart() {
        require(block.number >= startBlock);
        _;
    }
    
    modifier beforeEnd() {
        require(block.number <= endBlock);
        _;
    }
    
    function min(uint a, uint b) pure internal returns(uint) {
        if (a <= b) {
            return a;
        } else {
            return b;
        }
    }
    
    function placeBid() public payable notOwner afterStart beforeEnd {
        require(auctionState == State.Running);
        require(msg.value >= 100);
        
        uint currentBid = bids[msg.sender] + msg.value;        
        require(currentBid > highestBindingBid);
        
        bids[msg.sender] = currentBid;
        
        if (currentBid <= bids[highestBidder]) {
            highestBindingBid = min(currentBid + bidIncrement, bids[highestBidder]);
        } else {
            highestBindingBid = min(currentBid, bids[highestBidder] + bidIncrement);
            highestBidder = payable(msg.sender);
        }
    }
    
    function cancelAuction() public onlyOwner {
        auctionState = State.Cancelled;
    }
    
    function finalizeAuction() public {
        require(auctionState == State.Cancelled || block.number > endBlock);
        require(msg.sender == owner || bids[msg.sender] > 0);
        
        address payable recipient = payable(msg.sender);
        uint value;
        
        if (auctionState == State.Cancelled) {
            value = bids[msg.sender];
        } 
        else if (msg.sender == owner) {
            value = highestBindingBid;
        }
        else if (msg.sender == highestBidder) {
            value = bids[highestBidder] - highestBindingBid;
        }
        else {
            value = bids[msg.sender];
        }
        
        // Resetting bids of the recipient
        bids[recipient] = 0;
        
        // Transfering money
        recipient.transfer(value);
    }
}