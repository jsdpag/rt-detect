
function  v = evarchk( RewardMaxMs , RfXDeg , RfYDeg , RfRadDeg , ...
  RfWinFactor , FixTolDeg , BaselineMs , WaitAvgMs , WaitMaxProb , ...
    RewardSlope , RewardMinMs , RewardFailFrac , ScreenGamma , ItiMinMs )
% 
% evarchk( <ARCADE editable variables> )
% 
% Performs error checking on each variable. Returns struct v where each
% input variable is assigned to a field with the same name.
% 
  
  % Define inclusive limits to each numeric variable
  lim.RewardMaxMs = [ 0 , Inf ] ;
  lim.RfXDeg = [ -Inf , +Inf ] ;
  lim.RfYDeg = [ -Inf , +Inf ] ;
  lim.RfRadDeg = [ 0 , +Inf ] ;
  lim.RfWinFactor = [ 0 , +Inf ] ;
  lim.FixTolDeg = [ 0 , Inf ] ;
  lim.BaselineMs = [ 0 , Inf ] ;
  lim.WaitAvgMs = [ 0 , Inf ] ;
  lim.WaitMaxProb = [ 0 , 1 ] ;
  lim.RewardSlope = [ 0 , Inf ] ;
  lim.RewardMinMs = [ 0 , Inf ] ;
  lim.RewardFailFrac = [ 0 , 1 ] ;
  lim.ScreenGamma = [ 0 , Inf ] ;
  lim.ItiMinMs = [ 0 , Inf ] ;
  
  % Pack input into struct
  v.RewardMaxMs = RewardMaxMs ;
  v.RfXDeg = RfXDeg ;
  v.RfYDeg = RfYDeg ;
  v.RfRadDeg = RfRadDeg ;
  v.RfWinFactor = RfWinFactor ;
  v.FixTolDeg = FixTolDeg ;
  v.BaselineMs = BaselineMs ;
  v.WaitAvgMs = WaitAvgMs ;
  v.WaitMaxProb = WaitMaxProb ;
  v.RewardSlope = RewardSlope ;
  v.RewardMinMs = RewardMinMs ;
  v.RewardFailFrac = RewardFailFrac ;
  v.ScreenGamma = ScreenGamma ;
  v.ItiMinMs = ItiMinMs ;
  
  % Numeric variables
  for  N = fieldnames( v )' ; n = N{ 1 } ;
    
    % Check type
    if  ~ isa( v.( n ) , 'double' )
      
      error( '%s must be of type double' , n )
      
    % Limits
    elseif  v.( n ) < lim.( n )( 1 )  ||  v.( n ) > lim.( n )( 2 )
      
      error( '%s must be within inclusive range [ %.3f , %.3f ]' , ...
        n , lim.( n ) )
      
    end % checks
    
  end % num vars
  
end % evarchk

