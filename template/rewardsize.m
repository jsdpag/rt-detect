
function  y = rewardsize( e , p , s , m )
% 
% ms = rewardsize( e , p , s , m )
% 
% Calculate size of reward on upcoming trial. Counts N, the number of
% contiguous trials prior to the upcoming trial that all had error code e.
% Let x = N + p, where p is a probabiliy value in range [0,1]. Reward is
% defined as:
% 
%   y = ( 1 ./ ( 1 + exp( -s .* x ) ) - 0.5 ) * 2 * m
%   
% If p increases with the difficulty of the upcoming trial then the reward
% size will vary according to both the past (N) and expected upcoming (p)
% performance.
% 
% The shifted, scaled logistic function ensures that the reward size will
% saturate following a string of trials with outcome e. Also, upcoming
% difficulty (p) will have the greatest impact on reward size when
% following no trial with outcome e.
% 
% NOTE: Must call rewardsize in the task script.
% 
  
  % Performance on previous trials
  prevdata = getPreviousTrialData ;
  
  % Previous trials without the desired error code
  err = prevdata.trialError( 1 : end - 1 ) ~= e ;
  
  % Count contiguous previous trials with error e
  N = numel( err ) - find( err , 1 , 'last' ) ;
  
    % N is [ ] on first trial in session
    if  isempty( N ) , N = 0 ; end
  
  % Independent function variable
  x = N + p ;
  
  % Compute reward size
  y = ( 1 ./ ( 1 + exp( -s .* x ) ) - 0.5 ) * 2 * m ;
  
end % rewardsize

