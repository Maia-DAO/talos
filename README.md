# TALOS

<!--
Badges provide a quick visual way to convey various information about your project. Below are several common types of badges. Feel free to uncomment, remove, or add new badges as needed for your project. Make sure to update the links so they point to the correct sources relevant to your project.

- Version: Shows the current version of your project based on the latest release.
- Test CI: Displays the status of your continuous integration testing.
- Lint: Shows the status of your code linting process.
- Code Coverage: Indicates the percentage of your code covered by tests.
- License: Shows the type of license your project is under.
- Docs: Links to your project's documentation.
- Discord: Provides a quick link to join your Discord server.
- Discussions: (Optional) If you use GitHub Discussions, this badge links to that section.
- JS Library: (Optional) If your project includes a JavaScript library, use this badge to link to it.

Remember to replace 'Maia-DAO/foundry-template' with your repository's path and update other relevant links to reflect your project's resources.
-->

[![Version][version-badge]][version-link]
[![Test CI][ci-badge]][ci-link]
[![Lint][lint-badge]][lint-link]
[![Code Coverage][coverage-badge]][coverage-link]
[![Solidity][solidity-shield]][ci-link]
[![License][license-badge]][license-link]
[![Docs][docs-badge]][docs-link]
[![Discord][discord-badge]][discord-link]
<!-- [![Discussions][discussions-badge]][discussions-link] -->
<!-- [![JS Library][js-library-badge]][js-library-link] -->

Transparent Automated Liquidity Omnichain Strategies (TALOS) is a peer-to-peer system that was built to reduce the current huge barrier of entry for adoption of concentrated liquidity and elevate the current user experience, specifically for Uniswap V3.

## Contributing

If you’re interested in contributing please see our [contribution guidelines](./CONTRIBUTING.md)! This includes instructions on how to compile and run tests locally.

## Documentation

A more detailed description of the project can be found in the [documentation](https://v2-docs.maiadao.io/).

## Architecture

Talos positions are split into two main *Types*:

- **Vanilla**: Represent a share of one or more UNI V3 NFT positions.
- **Staked**: Represent a share of one or more UNI V3 NFT positions that are all staked in our Uniswap V3 Staker.

*Strategy Templates* encompass rebalancing and reranging strategies that work with both *Types* of positions without requiring any modifications.

New *Strategy Templates* can easily be created by solidity developers. There are multiple audited examples with guides of some possible operations.

The first *Strategy Template* holds a single UNI V3 NFT that anyone can create for any pool. When the price deviates a predefined number of ticks from the center of the position, anyone can call rebalance for the pool to set it at 50/50 again. There is an associated fee to these tasks – if the cost of constantly balancing the position is too large, it either won't happen or the pool or gas depositors may incur losses.

## Repository Structure

All contracts are held within the `./src` folder.

Note that helper contracts used by tests are held in the `./test/utils` subfolder within the contracts folder. Any new test helper contracts should be added there and all foundry tests are in the `./test` folder.

```ml
src
├── base
│   └── TalosBaseStrategy.sol
├── boost-aggregator
│   └── BoostAggregator.sol
├── factories
│   ├── BoostAggregatorFactory.sol
│   ├── OptimizerFactory.sol
│   ├── TalosBaseStrategyFactory.sol
│   ├── TalosManagerFactory.sol
│   ├── TalosStrategyStakedFactory.sol
│   └── TalosStrategyVanillaFactory.sol
├── interfaces
│   ├── AutomationCompatibleInterface.sol
│   ├── IBoostAggregatorFactory.sol
│   ├── IBoostAggregator.sol
│   ├── IOptimizerFactory.sol
│   ├── ITalosBaseStrategyFactory.sol
│   ├── ITalosBaseStrategy.sol
│   ├── ITalosManagerFactory.sol
│   ├── ITalosManager.sol
│   ├── ITalosOptimizer.sol
│   ├── ITalosStrategyStakedFactory.sol
│   ├── ITalosStrategyStaked.sol
│   └── ITalosStrategyVanillaFactory.sol
├── libraries
│   ├── PoolActions.sol
│   └── PoolVariables.sol
├── strategies
│   └── TalosStrategySimple.sol
├── TalosManager.sol
├── TalosOptimizer.sol
├── TalosStrategyStaked.sol
└── TalosStrategyVanilla.sol
test
├── BoostAggregatorTest.t.sol
├── factories
│   ├── BoostAggregatorFactoryTest.t.sol
│   ├── ComputeBoostAggregator.t.sol
│   └── OptimizerFactoryTest.t.sol
├── mocks
│   ├── MockBoostAggregatorFactory.sol
│   └── MockOptimizerFactory.sol
├── TalosOptimizerTest.t.sol
├── TalosStrategyStakedTest.t.sol
├── TalosStrategyVanillaTest.t.sol
├── TalosTestor.t.sol
└── utils
    ├── libraries
    │   ├── PoolActions.sol
    │   └── PoolVariables.sol
    └── UniswapV3Assistant.t.sol
```

## Local deployment and testing

To utilize the contracts in you can install the code in your repo with forge:

```bash
forge install https://github.com/Maia-DAO/talos
```

To run tests, first clone the repository, then setup .env following the .env.example file. After that, run the following command to install dependencies, compile and run tests:

```bash
forge test
```

## License

[MIT](LICENSE) Copyright <YEAR> <COPYRIGHT HOLDER>

<!-- 
Update the following badge links for your repository:
- Replace 'Maia-DAO/foundry-template' with your repository path.
- Replace Maia DAO Discord link with your Discord server invite link.
-->

[version-badge]: https://img.shields.io/github/v/release/Maia-DAO/foundry-template
[version-link]: https://github.com/Maia-DAO/foundry-template/releases
[ci-badge]: https://github.com/Maia-DAO/foundry-template/actions/workflows/test.yml/badge.svg
[ci-link]: https://github.com/Maia-DAO/foundry-template/actions/workflows/test.yml
[lint-badge]: https://github.com/Maia-DAO/foundry-template/actions/workflows/lint.yml/badge.svg
[lint-link]: https://github.com/Maia-DAO/foundry-template/actions/workflows/lint.yml
[coverage-badge]: .github/coverage-badge.svg
[coverage-link]: .github/coverage-badge.svg
[solidity-shield]: https://img.shields.io/badge/solidity-%5E0.8.0-aa6746
[license-badge]: https://img.shields.io/github/license/Maia-DAO/foundry-template
[license-link]: https://github.com/Maia-DAO/foundry-template/blob/main/LICENSE
[docs-badge]: https://img.shields.io/badge/Ecosystem-documentation-informational
[docs-link]: https://v2-docs.maiadao.io/
[discussions-badge]: https://img.shields.io/badge/foundry-template-discussions-blueviolet
[discussions-link]: https://github.com/Maia-DAO/foundry-template/discussions
[js-library-badge]: https://img.shields.io/badge/foundry-template.js-library-red
[js-library-link]: https://github.com/Maia-DAO/foundry-template-js
[discord-badge]: https://img.shields.io/static/v1?logo=discord&label=discord&message=Join&color=blue
[discord-link]: https://discord.gg/maiadao
