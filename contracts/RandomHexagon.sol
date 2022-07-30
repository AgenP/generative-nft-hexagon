//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "base64-sol/base64.sol";

contract RandomHexagon is ERC721URIStorage, VRFConsumerBase {
  bytes32 public keyHash;
  uint256 public fee;
  uint256 public tokenCounter;

  // SVG parameters
  string[] public strokes;
  string[] public fills;
  string[] public backgrounds;
  string[] public attributes;

  // This can be made internal.
  mapping(bytes32 => address) public requestIdToSender;
  mapping(bytes32 => uint256) public requestIdToTokenId;
  mapping(uint256 => uint256) public tokenIdToRandomNumber;

  event RequestedRandomSVG(bytes32 indexed requestId, uint256 indexed tokenId);
  event CreatedUnfinishedRandomSVG(
    uint256 indexed tokenId,
    uint256 randomNumber
  );
  event CreatedRandomSVG(uint256 indexed tokenId, string tokenURI);

  constructor(
    address _vrfCoordinator,
    address _linkToken,
    bytes32 _keyHash,
    uint256 _fee
  )
    VRFConsumerBase(_vrfCoordinator, _linkToken)
    ERC721("Random SVGNFT", "RSNFT")
  {
    tokenCounter = 0;
    keyHash = _keyHash;
    fee = _fee;
    strokes = ["gold", "blue", "green"];
    fills = ["yellow", "black", "white"];
    backgrounds = ["#000000", "#B61792", "#AB770F", "#FF0061"];
    attributes = ["Sharp", "Shiny", "Mystic"];
  }

  function create() public returns (bytes32 requestId) {
    requestId = requestRandomness(keyHash, fee);
    requestIdToSender[requestId] = msg.sender;
    uint256 tokenId = tokenCounter;
    requestIdToTokenId[requestId] = tokenId;
    tokenCounter += 1;
    emit RequestedRandomSVG(requestId, tokenId);
  }

  // The chainliunk VRF has a max gas of 200000 but we will be using ~2M gas.
  // So the SVG will be done in finishMint()
  function fulfillRandomness(bytes32 requestId, uint256 _randomNumber)
    internal
    override
  {
    address nftOwner = requestIdToSender[requestId];
    uint256 tokenId = requestIdToTokenId[requestId];
    _safeMint(nftOwner, tokenId);
    tokenIdToRandomNumber[tokenId] = _randomNumber;
    emit CreatedUnfinishedRandomSVG(tokenId, _randomNumber);
  }

  function finishMint(uint256 _tokenId) public {
    require(bytes(tokenURI(_tokenId)).length <= 0, "Token URI already set!");
    require(tokenCounter > _tokenId, "TokenId has not been minted yet!");
    require(
      tokenIdToRandomNumber[_tokenId] > 0,
      "There is no NFT for this tokenId or wait for the Chainlink VRF"
    );
    uint256 randomNumber = tokenIdToRandomNumber[_tokenId];
    string memory svg = generateSVG(randomNumber);
    string memory imageURI = svgToImageURI(svg);
    string memory tokenURI = formatTokenURI(imageURI, randomNumber);
    _setTokenURI(_tokenId, tokenURI);
    emit CreatedRandomSVG(_tokenId, svg);
  }

  function generateSVG(uint256 _randomNumber)
    public
    view
    returns (string memory finalSvg)
  {
    //Single quotes used inside the double quotes to make it the same string
    // abi.encodePacked is used since we are using string concatenation
    string memory backgroundcolor = backgrounds[
      ((_randomNumber) % backgrounds.length)
    ];
    string memory strokecolor = strokes[
      ((_randomNumber + 59) % strokes.length)
    ];
    string memory fillcolor = fills[((_randomNumber + 23) % fills.length)];
    finalSvg = string(
      abi.encodePacked(
        "<svg xmlns= 'http://www.w3.org/2000/svg' height='",
        "500",
        "' width='",
        "500",
        "'><rect fill='",
        backgroundcolor,
        "' height='",
        "250",
        "' width= '",
        "500",
        "'></rect><polygon points='",
        "200,125 ",
        "233,165 ",
        "267,165 ",
        "300,125 ",
        "267,85 ",
        "233,85",
        "' style='"
        "fill:",
        fillcolor,
        ";stroke:",
        strokecolor,
        ";stroke-width:2"
        "' />"
      )
    );
    finalSvg = string(abi.encodePacked(finalSvg, "</svg>"));
  }

  function svgToImageURI(string memory svg)
    public
    pure
    returns (string memory)
  {
    // example:
    // <svg width='500' height='500' viewBox='0 0 285 350' fill='none' xmlns='http://www.w3.org/2000/svg'><path fill='black' d='M150,0,L75,200,L225,200,Z'></path></svg>
    // data:image/svg+xml;base64, <base64 encode>
    string memory baseURL = "data:image/svg+xml;base64,";
    string memory svgBase64Encoded = Base64.encode(
      bytes(string(abi.encodePacked(svg)))
    );
    // Concated baseURL + Base 64 encoded svg image
    return string(abi.encodePacked(baseURL, svgBase64Encoded));
  }

  // Json formatting (Has a new base url)
  function formatTokenURI(string memory imageURI, uint256 _randomNumber)
    public
    view
    returns (string memory)
  {
    string memory attribute = attributes[
      ((_randomNumber + 6) % attributes.length)
    ];
    return
      string(
        abi.encodePacked(
          "data:application/json;base64,",
          Base64.encode(
            bytes(
              abi.encodePacked(
                '{"name":"',
                "A Generative SVG Hexagon",
                '", "description":"A fully on-chain Hexagon NFT!", "attributes":[{"trait_type": "Base", "value": "',
                attribute,
                '"}], "image":"',
                imageURI,
                '"}'
              )
            )
          )
        )
      );
  }
}
