//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "base64-sol/base64.sol";

contract RandomSVG is ERC721URIStorage, VRFConsumerBase {
  bytes32 public keyHash;
  uint256 public fee;
  uint256 public tokenCounter;

  // SVG parameters
  uint256 public maxNumberOfPaths;
  uint256 public maxNumberOfPathCommands;
  uint256 public size;
  string[] public pathCommands;
  string[] public colors;

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
    maxNumberOfPaths = 10;
    maxNumberOfPathCommands = 5;
    size = 500;
    pathCommands = ["M", "L"];
    colors = ["red", "blue", "green", "yellow", "black", "white"];
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
    string memory tokenURI = formatTokenURI(imageURI);
    _setTokenURI(_tokenId, tokenURI);
    emit CreatedRandomSVG(_tokenId, svg);
  }

  function generateSVG(uint256 _randomNumber)
    public
    view
    returns (string memory finalSvg)
  {
    uint256 numberOfPaths = (_randomNumber % maxNumberOfPaths) + 1;
    //Single quotes used inside the double quotes to make it the same string
    // abi.encodePacked is used since we are using string concatenation
    finalSvg = string(
      abi.encodePacked(
        "<svg xmlns= 'http://www.w3.org/2000/svg' height='",
        uint2str(size),
        "' width='",
        uint2str(size),
        "'>"
      )
    );
    for (uint256 i = 0; i < numberOfPaths; i++) {
      uint256 newRNG = uint256(keccak256(abi.encode(_randomNumber, i)));
      string memory pathSvg = generatePath(newRNG);
      finalSvg = string(abi.encodePacked(finalSvg, pathSvg));
    }
    finalSvg = string(abi.encodePacked(finalSvg, "</svg>"));
  }

  function generatePath(uint256 _randomNumber)
    public
    view
    returns (string memory pathSvg)
  {
    uint256 numberOfPathCommands = (_randomNumber % maxNumberOfPathCommands) +
      1;
    pathSvg = "<path d='";
    for (uint256 i = 0; i < numberOfPathCommands; i++) {
      uint256 newRNG = uint256(keccak256(abi.encode(_randomNumber, size + i)));
      string memory pathCommand = generatePathCommand(newRNG);
      pathSvg = string(abi.encodePacked(pathSvg, pathCommand));
    }
    string memory color = colors[_randomNumber % colors.length];
    pathSvg = string(
      abi.encodePacked(pathSvg, "' fill='transparent' stroke='", color, "'/>")
    );
  }

  function generatePathCommand(uint256 _randomNumber)
    public
    view
    returns (string memory pathCommand)
  {
    pathCommand = pathCommands[_randomNumber % pathCommands.length];
    uint256 parameterOne = uint256(
      keccak256(abi.encode(_randomNumber, size * 2))
    ) % size;
    uint256 parameterTwo = uint256(
      keccak256(abi.encode(_randomNumber, size * 3))
    ) % size;
    pathCommand = string(
      abi.encodePacked(
        pathCommand,
        " ",
        uint2str(parameterOne),
        " ",
        uint2str(parameterTwo)
      )
    );
  }

  // From: https://stackoverflow.com/a/65707309/11969592
  function uint2str(uint256 _i)
    internal
    pure
    returns (string memory _uintAsString)
  {
    if (_i == 0) {
      return "0";
    }
    uint256 j = _i;
    uint256 len;
    while (j != 0) {
      len++;
      j /= 10;
    }
    bytes memory bstr = new bytes(len);
    uint256 k = len;
    while (_i != 0) {
      k = k - 1;
      uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
      bytes1 b1 = bytes1(temp);
      bstr[k] = b1;
      _i /= 10;
    }
    return string(bstr);
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
  function formatTokenURI(string memory imageURI)
    public
    pure
    returns (string memory)
  {
    return
      string(
        abi.encodePacked(
          "data:application/json;base64,",
          Base64.encode(
            bytes(
              abi.encodePacked(
                '{"name":"',
                "SVG Hexagon", // You can add whatever name here
                '", "description":"A fully on-chain Hexagon NFT!", "attributes":"", "image":"',
                imageURI,
                '"}'
              )
            )
          )
        )
      );
  }
}
