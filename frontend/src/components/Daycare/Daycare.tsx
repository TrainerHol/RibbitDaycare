import React, {useContext, useEffect, useState} from 'react';
import {BigNumber, ethers} from 'ethers';
import {RibbitDaycareContext} from "./../../hardhat/SymfoniContext";
import { formatEther } from 'ethers/lib/utils';

interface Props { }

export const RibbitDaycare: React.FC<Props> = () => {
    const ribbitdaycare = useContext(RibbitDaycareContext)
    const [wRBTBalance, setUserwRBTBalance] = useState("");
    const provider = new ethers.providers.Web3Provider(window.ethereum);
    const signer = provider.getSigner();
    useEffect(() => {
        const doAsync = async () => {
            if (!ribbitdaycare.instance) return
            console.log("RibbitDaycare is deployed at ", ribbitdaycare.instance.address)

        };
        doAsync();
    }, [ribbitdaycare]);


    const handleSetGreeting = async (e: React.MouseEvent<HTMLButtonElement, MouseEvent>) => {
        e.preventDefault()
        if (!ribbitdaycare.instance) throw Error("RibbitDaycare instance not ready")
        if (ribbitdaycare.instance) {
            const address = await signer.getAddress();
            const tx =  await ribbitdaycare.instance.stakerBalances(address);
            setUserwRBTBalance(formatEther(tx));
            console.log("Getting staker balances for " + address, formatEther(tx));
        }
    }
    return (
        <div>
            <div>{wRBTBalance} wRBT</div>
            <button onClick={(e) => handleSetGreeting(e)}>Fetch wRBT Balance</button>
        </div>
    )
}