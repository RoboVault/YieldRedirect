# YieldRedirect

High level diagram : https://docs.google.com/presentation/d/19rIYszHu9z9tMoAOn5ChnAcuUOKm3FGWityTPt_AweI/edit?usp=sharing

Yield redirect has two versions 
1) deposits assets (i.e. LP) to some yield farm & automatically converts farming rewards to some target asset (i.e USDC or yvUSDC) 
2) deposits assets to some vault & automatically converts farming rewards to some target asset (i.e. deposit WFTM -> earn yield from yvWFTM -> convert yield to USDC)

Target asset can be a token i.e. USDC or can be configured so that yields are swapped to USDC & deposited into a vault allowing users to later harvest IBT i.e. harvest yvUSDC so rewards are earning yield 
(potential risks of using yvUSDC / rvUSDC is if vault deposit limit is reached then yield redirect will be bricked until)
V1 will likelly be simply redirecting LP farming rewards to stable coins as MVP 
with V2 introducing IBT as the target token 

A number of high level tests have been written and configured to test protocol using combination of Spooky / LQDR farms & yearn vaults. 
