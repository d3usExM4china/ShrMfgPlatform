//SPDX-License-Identifier: MIT
pragma solidity^0.8.0;

import "./ScamCoin.sol";

contract Pool is ScamCoin {

    constructor(address[] memory packages) ScamCoin(packages) {
    // packages => [0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db, 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB]
    // Addresses of all packages that will get their coins minted upon deployment of the contract 
    }

   //STORAGE
    struct Offer {
        string id;
        address client;
        address redirectingManufacturer;
        address acceptingManufacturer;
        uint price;
        uint8 state;
        uint endDate;
    }

    Offer[] public offers;
    mapping (string => uint) idToIndex;
    mapping (string => uint) directIdToDecrement;

    /*  id -> unique offer ID;
        client -> client address(package);
        redirectingManufacturer -> redirecting manufacturer address(storage unit),
        acceptingManufacturer -> accepting manufacturer address(storage unit), if offer is open, value is address(0)
        price -> price of the redirected offer, is always lower than the price of the original direct offer 
                 (redirecting manufacturer decrements it)
        state -> 0 : offer was redirected to pool and is open for manufacturers to respond, 
                 1 : offer was accepted by a manufacturer,
                 2 : offer was removed by the redirecting manufacturer;
        endDate -> Seconds in unix time until offer's expiration time;
    */


    // MAIN FUNCTIONS (CALLABLES)
    function acceptOffer(string memory _id) endDateIsValidPlus(_id) offerIsOpen(_id) senderIsNotPublisher(_id) public {
        Offer memory myOffer = getOffer(_id);
        uint offerIndex = idToIndex[_id];
        offers[offerIndex].state = 1;
        offers[offerIndex].acceptingManufacturer = msg.sender;
        emit acceptedOffer(myOffer);
         // Needs to be paired up with forkFunds() call from the client acount, to remove transfer privileges, immediately upon resolving ^
    }

    function removeOffer(string memory _id) public senderIsPublisher(_id) offerIsOpen(_id) {
        Offer memory myOffer = getOffer(_id);
        uint offerIndex = idToIndex[_id];
        offers[offerIndex].state = 2;
        emit removedOffer(myOffer);
        // Needs to be paired up with decreaseAllowance() call from the client acount, immediately upon resolving ^ 
    }

   function forkFunds(string memory _id) public senderIsRedirectingManufacturer(_id) offerWasAccepted(_id) {
        Offer memory myOffer = getOffer(_id);
        transferFrom(myOffer.client, myOffer.acceptingManufacturer, myOffer.price * 10**18);
        transferFrom(myOffer.client, msg.sender, directIdToDecrement[_id] * 10**18);
    }



    // CO-MAIN FUNCTIONS (ONLY CALLED BY CALLABLES, NEVER DIRECTLY)
    function getOffer(string memory _id) public view offerExists(_id) returns(Offer memory) {
        uint offerIndex = idToIndex[_id];
        return offers[offerIndex];
    }

    function addOffer(string memory _id, address _client, uint _price, uint _endDate) idIsUnique(_id) endDateIsValid(_endDate) public {
        offers.push(Offer(_id, _client, msg.sender, address(0), _price, 0, _endDate));
        idToIndex[_id] = offers.length - 1;
        emit newOffer(offers[offers.length - 1]);
    }



    // EVAL FUNCTIONS (USED FOR MODIFIERS)
    function isOfferUnique(string memory _id) public view returns(bool) {
        for(uint i=0; i<offers.length; i++) {
            if(keccak256(abi.encodePacked(offers[i].id)) == keccak256(abi.encodePacked(_id))) {
                return false;
            }
        }
        return true;
    }

    function isEndDateValid(string memory _id) public view returns(bool) {
        Offer memory myOffer = getOffer(_id);
        if (myOffer.endDate < block.timestamp) {
            return false;
        }
        return true;
    }

    function isOfferOpen(string memory _id) public view returns(bool) {
        Offer memory myOffer = getOffer(_id);
        if (myOffer.state == 0) {
            return true;
        }
        return false;
    }

    function isSenderAlsoPublisher(string memory _id) public view returns(bool) {
        Offer memory myOffer = getOffer(_id);
        if (msg.sender == myOffer.redirectingManufacturer) {
            return true;
        }
        return false;
    }

    function isSenderAlsoRedirectingManufacturer(string memory _id) public view returns(bool) {
        Offer memory myOffer = getOffer(_id);
        if (msg.sender == myOffer.redirectingManufacturer) {
            return true;
        }
        else {
        return false;
        }
    }

    function isOfferAccepted(string memory _id) public view returns(bool) {
        Offer memory myOffer = getOffer(_id);
        if (myOffer.state == 1) {
            return true;
        }
        else {
            return false;
        }
    }


    // MODIFIERS
    modifier idIsUnique(string memory _id) {
        require(isOfferUnique(_id), "Offer ID already in use.");
        _;
    }

    modifier offerExists(string memory _id) {
        require(isOfferUnique(_id) == false, "Offer ID not found");
        _;
    }

    modifier endDateIsValid(uint _endDate) {
        require(block.timestamp < _endDate, "Enddate is in the past");
        _;
    }

    modifier endDateIsValidPlus(string memory _id) {
        require(isEndDateValid(_id), "End date is in the past");
        _;
    }

    modifier offerIsOpen(string memory _id) {
        require(isOfferOpen(_id), "Offer is not open");
        _;
    }

    modifier senderIsPublisher(string memory _id) {
        require(isSenderAlsoPublisher(_id), "You are attempting to remove an offer, published by somebody else");
        _;
    }

    modifier senderIsNotPublisher(string memory _id) {
        require(isSenderAlsoPublisher(_id) == false , "You are attempting to accept your own offer");
        _;
    }

    modifier senderIsRedirectingManufacturer(string memory _id) {
        require(isSenderAlsoRedirectingManufacturer(_id), "You are not redirecting manufacturer of the offer you are trying to fork funds for");
        _;
    }

    modifier offerWasAccepted(string memory _id) {
        require(isOfferAccepted(_id), "Offer was not accepted");
        _;
    }




    // EVENTS 
    event newOffer(Offer);

    event acceptedOffer(Offer);

    event removedOffer(Offer);

}
