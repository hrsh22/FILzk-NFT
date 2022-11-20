pragma solidity ^0.8.1;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "./mint.sol";
import "./revealAttribute1.sol";
import "./revealAttribute2.sol";
import "./revealAttribute3.sol";
import "./revealNFT.sol";

struct character {
    uint256 attribute1;
    uint256 attribute2;
    uint256 attribute3;
    uint256 cHash;
    bool isRevealed;
}

contract FILZK is ERC721Enumerable, Ownable {
    RevealVerifier public revealVerifier;
    MintVerifier public mintVerifier;
    PartialRevealVerifier1 public partialRevealVerifier1;
    PartialRevealVerifier2 public partialRevealVerifier2;
    PartialRevealVerifier3 public partialRevealVerifier3;

    mapping(uint256 => character) public characters;
    mapping(uint256 => mapping(address => uint256)) public bids; // tokenId -> user -> amount
    mapping(address => uint256) public balances;
    mapping(uint256 => address) public ogOwners; // owner => tokenId
    uint256 public tokenId = 0;

    event PartialReveal1(uint256 _tokenId, uint256 _partialProofId);
    event PartialReveal2(uint256 _tokenId, uint256 _partialProofId);
    event PartialReveal3(uint256 _tokenId, uint256 _partialProofId);
    event CreateBid(uint256 _tokenId, address _buyer, uint256 _amount);
    event AcceptBid(
        uint256 _tokenId,
        address _owner,
        address _buyer,
        uint256 _amount
    );

    constructor() ERC721("FILzk", "FILzk") {
        transferOwnership(msg.sender);
        revealVerifier = new RevealVerifier();
        mintVerifier = new MintVerifier();
        partialRevealVerifier1 = new PartialRevealVerifier1();
        partialRevealVerifier2 = new PartialRevealVerifier2();
        partialRevealVerifier3 = new PartialRevealVerifier3();
    }

    // Mint NFT: User chooses three attributes in private that satisfy a certain criteria, for instance
    // they sum up to 20. Users can only mint for themselves.
    function mint(
        uint256[2] memory _a,
        uint256[2][2] memory _b,
        uint256[2] memory _c,
        uint256[1] memory _publicInputs
    ) public {
        require(
            mintVerifier.mintVerify(_a, _b, _c, _publicInputs),
            "Proof is not valid"
        );
        _mint(msg.sender, tokenId);
        characters[tokenId].cHash = _publicInputs[0];
        characters[tokenId].isRevealed = false;
        ogOwners[tokenId] = msg.sender;
        tokenId++;
    }

    // Reveal full NFT. Attributes revealed by the owner will be recorded.
    function reveal(
        uint256[2] memory _a,
        uint256[2][2] memory _b,
        uint256[2] memory _c,
        uint256[4] memory _publicInputs,
        uint8 _tokenId
    ) public {
        require(revealVerifier.verifyRevealProof(_a, _b, _c, _publicInputs));
        require(characters[_tokenId].cHash == _publicInputs[0], "Invalid hash");
        characters[_tokenId].attribute1 = _publicInputs[1];
        characters[_tokenId].attribute2 = _publicInputs[2];
        characters[_tokenId].attribute3 = _publicInputs[3];
        characters[_tokenId].isRevealed = true;
    }

    // Partial reveal
    // Users can selectively reveal attributes about their NFT. For instance, they can prove that
    // a certain attribute is greater than X number, without revealing such attribute.
    // For the seller, this is effective in driving up speculation while maintaining leverage over information assymetry
    function partialReveal1(
        uint256[2] memory _a,
        uint256[2][2] memory _b,
        uint256[2] memory _c,
        uint256[1] memory _publicInputs,
        uint8 _tokenId
    ) public {
        require(
            partialRevealVerifier1.verifyPartialRevealProof1(
                _a,
                _b,
                _c,
                _publicInputs
            )
        );
        require(characters[_tokenId].cHash == _publicInputs[0], "Invalid hash");
        emit PartialReveal1(_tokenId, 1);
    }

    function partialReveal2(
        uint256[2] memory _a,
        uint256[2][2] memory _b,
        uint256[2] memory _c,
        uint256[1] memory _publicInputs,
        uint8 _tokenId
    ) public {
        require(
            partialRevealVerifier2.verifyPartialRevealProof2(
                _a,
                _b,
                _c,
                _publicInputs
            )
        );
        require(characters[_tokenId].cHash == _publicInputs[0], "Invalid hash");
        emit PartialReveal2(_tokenId, 1);
    }

    function partialReveal3(
        uint256[2] memory _a,
        uint256[2][2] memory _b,
        uint256[2] memory _c,
        uint256[1] memory _publicInputs,
        uint8 _tokenId
    ) public {
        require(
            partialRevealVerifier3.verifyPartialRevealProof3(
                _a,
                _b,
                _c,
                _publicInputs
            )
        );
        require(characters[_tokenId].cHash == _publicInputs[0], "Invalid hash");
        emit PartialReveal3(_tokenId, 1);
    }

    // Create a bid on the NFT
    function createBid(uint256 _tokenId) public payable notOwnerOf(_tokenId) {
        require(_tokenId <= tokenId, "Invalid NFT");
        bids[_tokenId][msg.sender] = msg.value;
        emit CreateBid(_tokenId, msg.sender, msg.value);
    }

    // Accept a bid on the NFT. If the owner is an original owner, they must reveal the NFT along with
    // the bid. If not, no proof is needed since all attributes are revealed already.
    function acceptBid(
        uint256[2] memory _a,
        uint256[2][2] memory _b,
        uint256[2] memory _c,
        uint256[4] memory _input,
        uint256 _tokenId,
        address _buyer
    ) public {
        if (ogOwners[_tokenId] == msg.sender) {
            require(
                revealVerifier.verifyRevealProof(_a, _b, _c, _input),
                "Invalid proof"
            ); // only og owners require proof
        }
        require(ownerOf(_tokenId) == msg.sender, "Not owner");
        balances[msg.sender] += bids[_tokenId][_buyer];
        transferFrom(msg.sender, _buyer, _tokenId);
        emit AcceptBid(_tokenId, msg.sender, _buyer, bids[_tokenId][_buyer]);
    }

    // Withdraw all balance from contract
    function withdraw() public {
        uint256 amount = balances[msg.sender];
        require(amount != 0, "Balance is empty");
        balances[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    // Modifiers
    modifier notOwnerOf(uint256 _tokenId) {
        require(ownerOf(_tokenId) != msg.sender, "Same owner");
        _;
    }
}
