import React, {useContext, useEffect, useState} from 'react';
import ethers from 'ethers';
import {RibbitDaycareContext} from "./../../hardhat/SymfoniContext";

interface Props { }

export const RibbitDaycare: React.FC<Props> = () => {
    const ribbitdaycare = useContext(RibbitDaycareContext)
    const [wRBTBalance, setUserwRBTBalance] = useState("");
    const provider = new ethers.providers.JsonRpcProvider();
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
            const tx = await ribbitdaycare.instance.stakerBalances(await signer.getAddress());
            setUserwRBTBalance(tx.toString);
            console.log("Getting staker balances tx", tx);
        }
    }
    return (
        <div>
            <div>{wRBTBalance}</div>
            <button onClick={(e) => handleSetGreeting(e)}>Fetch wRBT Balance</button>
        </div>
    )
}