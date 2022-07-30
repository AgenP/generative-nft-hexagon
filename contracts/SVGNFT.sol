//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "base64-sol/base64.sol";

contract SVGNFT is ERC721URIStorage, Ownable {
  uint256 public tokenCounter;
  event CreatedSVGNFT(uint256 indexed tokenId, string tokenURI);

  constructor() ERC721("SVG NFT", "svgNFT") {
    tokenCounter = 0;
  }

  function create(string memory svg) public {
    _safeMint(msg.sender, tokenCounter);
    string memory imageURI = svgToImageURI(svg);
    _setTokenURI(tokenCounter, formatTokenURI(imageURI));
    tokenCounter = tokenCounter + 1;
    emit CreatedSVGNFT(tokenCounter, svg);
  }

  // You could also just upload the raw SVG and have solildity convert it! --> to test!
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
