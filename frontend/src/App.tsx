import React from 'react';
import logo from './logo.svg';
import './App.css';
import {ethers} from 'ethers';
import { RibbitDaycare} from './components/Daycare/Daycare';
import { Symfoni } from './hardhat/SymfoniContext';

function App() {
  const provider = new ethers.providers.Web3Provider(window.ethereum, "any");
  provider.on("network", (newNetwork, oldNetwork) => {
      // When a Provider makes its initial connection, it emits a "network"
      // event with a null oldNetwork along with the newNetwork. So, if the
      // oldNetwork exists, it represents a changing network
      if (oldNetwork) {
          window.location.reload();
      }
  });
  return (
    <div className="App">
      <header className="App-header">
        <img src={logo} className="App-logo" alt="logo" />
        <Symfoni autoInit={true}>
        <RibbitDaycare></RibbitDaycare>
        </Symfoni>
      </header>
    </div>
  );
}

export default App;
