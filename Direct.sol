//SPDX-License-Identifier: MIT
pragma solidity^0.8.0;
import "./Pool.sol";


contract Direct is Pool {

    constructor(address[] memory packages) Pool(packages) {
    // packages => [0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db, 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB]
    }

    // STORAGE
    struct directOffer {
        string id;
        address client;
        address manufacturer;
        uint price;
        uint state;
        uint endDate;
    }
 
    /*
    state: 0 -> offer sent;
           1 -> offer accepted;
           2 -> offer redirected to pool;
           3 -> offer declined;
    */

    // SAMPLE DATA  ("offerOne", "0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2", "40", "1789421106") (address1 sends to address2)
    // FOR TESTING: ("offerTwo", "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4", "40",  "1789421106") (address2 sends to address1)
    //              ("offerOne", "10", "1789421106") (redirect)

    directOffer[] public directOffers;
    mapping (string => uint) directIdToIndex;


    // MAIN FUNCTIONS (CALLABLES)
    function sendDirectOffer(string memory _id, address payable  _manufacturer, uint _price, uint _endDate) idIsUnique(_id) endDateIsValid(_endDate) public {
        require(msg.sender != _manufacturer, "You cannot send a direct Offer to yourself");
        if (allowance(_manufacturer, msg.sender) == 0) {
            approve(_manufacturer, _price * 10**18); 
            // If address has not been approved before by manufacturer, it will add transfer privileges up to the _price amount ^
        }
        else {
            increaseAllowance(_manufacturer, _price * 10**18);
            // If address had already been approved, it will simply add _price-amount to allowances[owner][spender] ^
        }
        directOffers.push(directOffer(_id, msg.sender, _manufacturer, _price, 0, _endDate));
        directIdToIndex[_id] = directOffers.length - 1;
        
    }

    function acceptDirectOffer(string memory _id) public responderIsTarget(_id) directOfferIsSent(_id) directOfferNotExpired(_id)  {
        directOffer memory myOffer = getDirectOffer(_id); 
        uint myIndex = directIdToIndex[_id];
        directOffers[myIndex].state = 1;
        transferFrom(myOffer.client, msg.sender, myOffer.price * 10**18);
        // Transfers tokens (price amount) to accepting-manufacturer, from client who sent offer ^
        emit acceptedDirectOffer(myOffer);
    }


    function redirectOfferToPool(string memory _id, uint _decrement, uint _endDate) public responderIsTarget(_id) directOfferIsSent(_id) directOfferNotExpired(_id) {
        directOffer memory myOffer = getDirectOffer(_id);
        uint myIndex = directIdToIndex[_id];
        directOffers[myIndex].state = 2;
        addOffer(_id, myOffer.client, myOffer.price - _decrement, _endDate);
        directIdToDecrement[_id] = _decrement;
        emit redirectedDirectOffer(myOffer);
    }
    // 

    function declineDirectOffer(string memory _id) public responderIsTarget(_id) directOfferIsSent(_id) {
        directOffer memory myOffer = getDirectOffer(_id);
        uint myIndex = directIdToIndex[_id];
        directOffers[myIndex].state = 3;
        emit declinedDirectOffer(myOffer);
        // Needs to be paired up with a decreaseAllowance() call from the client acount, to remove transfer privileges, immediately upon resolving ^
    }



    // EVAL FUNCTIONS 
    function isDirectOfferIdUnique(string memory _id) public view returns(bool) {
        for(uint i=0; i<directOffers.length; i++)  {
            if(keccak256(abi.encodePacked(directOffers[i].id)) == keccak256(abi.encodePacked(_id))) {
                return false;
            }
        } return true;
    }

    function getDirectOffer(string memory _id) public view directOfferExists(_id) returns(directOffer memory) {
        uint offerIndex = directIdToIndex[_id];
        return directOffers[offerIndex];
    }

    function getAllActiveDirectOffers() public view returns(directOffer[] memory) {
       directOffer[] memory offersToMe;
       uint counter;
       for (uint i=0; i<directOffers.length; i++) {
           if (directOffers[i].manufacturer == msg.sender && directOffers[i].endDate > block.timestamp) {
               offersToMe[counter] = directOffers[i];
               counter++;
           }
       }
       return offersToMe;    
    }

    function isDirectOfferSent(string memory _id) public view returns(bool) {
        directOffer memory myOffer = getDirectOffer(_id);
        if (myOffer.state == 0) {
            return true;
        }
        return false;
    }

    function isDirectOfferExpired(string memory _id) public view returns(bool) {
        directOffer memory myOffer = getDirectOffer(_id);
        if (myOffer.endDate < block.timestamp) {
            return true;
        }
        return false;
    }

    function isResponderAlsoTarget(string memory _id) public view returns(bool) {
        directOffer memory myOffer = getDirectOffer(_id);
        if (myOffer.manufacturer == msg.sender) {
            return true;
        }
        return false;
    }



    // MODIFIERS
    modifier directOfferIdIsUnique(string memory _id) {
        require(isDirectOfferIdUnique(_id), "Provided directOfferID already in use");
        _;
    }

    modifier directOfferExists(string memory _id) {
        require(isDirectOfferIdUnique(_id) == false, "directOffer ID not found");
        _;
    }

    modifier directOfferIsSent(string memory _id) {
        require(isDirectOfferSent(_id), "directOffer, you are attempting to respond to is not sent (directOffer.state != 0)");
        _;
    }

    modifier directOfferNotExpired(string memory _id) {
        require(isDirectOfferExpired(_id) == false, "Offer has expired (directOffer.endDate > block.timestamp)");
        _;
    }

    modifier responderIsTarget(string memory _id) {
        require(isResponderAlsoTarget(_id), "Offer you are trying to respond to was not directed at your address (directOffer.manufacturer != msg.sender)");
        _;
    }



     // EVENTS 
    event newDirectOffer(directOffer);

    event acceptedDirectOffer(directOffer);

    event redirectedDirectOffer(directOffer);

    event declinedDirectOffer(directOffer);

    
    // DEBUG & TEST FUNCTIONS 
    function wipeClean() public {
        // wipe storage 
        delete directOffers;
        delete offers;
        // mappings cannot be wiped clean but it does not matter, since
        // every key comes from a hashing function and is unique.
        // Multiple offers will get the same index, but that index
        // will correctly correspond to the index in arrays, since
        // arrays can get wiped clean.
    }
    

    function sendScam(address _address, uint amount) public {
        _mint(_address, amount * 10**18);
    }
}
    
