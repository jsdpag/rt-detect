
function  v = evarchk( RewardMaxMs , RfXDeg , RfYDeg , RfRadDeg , ...
  RfWinFactor , RfTargetFactor , FixTolDeg , TrainingMode , BaselineMs ,...
    WaitAvgMs , WaitMaxProb , ReacTimeMinMs , RespWinWidMs , ...
      RewardSlope , RewardMinMs , RewardFailFrac , ScreenGamma , ...
        ItiMinMs , BehaviourXaxis , TdtHostPC , TdtExperiment , ...
          LaserCtrl , LaserBuffer , LaserSwitch , PowerScaleCoef , ...
            NumLaserChanOut , TdtChannels , SpikeBuffer , MuaStartIndex,...
              MuaBuffer , LfpStartIndex , LfpBuffer , StimRespSim )
% 
% evarchk( <ARCADE editable variables> )
% 
% Performs error checking on each variable. Returns struct v where each
% input variable is assigned to a field with the same name.
% 
  
  % Define inclusive limits to each Numeric variable, or the set of valid
  % strings for a Text variable
  lim.RewardMaxMs = [ 0 , Inf ] ;
  lim.RfXDeg = [ -Inf , +Inf ] ;
  lim.RfYDeg = [ -Inf , +Inf ] ;
  lim.RfRadDeg = [ 0 , +Inf ] ;
  lim.RfWinFactor = [ 0 , +Inf ] ;
  lim.RfTargetFactor = [ 0 , +Inf ] ;
  lim.FixTolDeg = [ 0 , Inf ] ;
  lim.TrainingMode = { 'off' , 'trial' , 'block' } ;
  lim.BaselineMs = [ 0 , Inf ] ;
  lim.WaitAvgMs = [ 0 , Inf ] ;
  lim.WaitMaxProb = [ 0 , 1 ] ;
  lim.ReacTimeMinMs = [ 0 , Inf ] ;
  lim.RespWinWidMs = [ 0 , Inf ] ;
  lim.RewardSlope = [ 0 , Inf ] ;
  lim.RewardMinMs = [ 0 , Inf ] ;
  lim.RewardFailFrac = [ 0 , 1 ] ;
  lim.ScreenGamma = [ 0 , Inf ] ;
  lim.ItiMinMs = [ 0 , Inf ] ;
  lim.BehaviourXaxis = { 'Contrast' , 'LaserFreqHz' , 'LaserPhaseDeg' , ...
    'LaserMaxPowerPerChan_mW' } ;
  lim.TdtHostPC = { } ;
  lim.TdtExperiment = { } ;
  lim.LaserCtrl = { } ;
  lim.LaserBuffer = { } ;
  lim.LaserSwitch = { } ;
  lim.PowerScaleCoef = [ 0 , 100 ] ;
  lim.NumLaserChanOut = [ 1 , Inf ] ;
  lim.TdtChannels = [ 1 , 32 ] ;
  lim.SpikeBuffer = { } ;
  lim.MuaStartIndex = [ 1 , 32 ] ;
  lim.MuaBuffer = { } ;
  lim.LfpStartIndex = [ 1 , 32 ] ;
  lim.LfpBuffer = { } ;
  lim.StimRespSim = { } ;
  
  % Pack input into struct
  v.RewardMaxMs = RewardMaxMs ;
  v.RfXDeg = RfXDeg ;
  v.RfYDeg = RfYDeg ;
  v.RfRadDeg = RfRadDeg ;
  v.RfWinFactor = RfWinFactor ;
  v.RfTargetFactor = RfTargetFactor ;
  v.FixTolDeg = FixTolDeg ;
  v.TrainingMode = TrainingMode ;
  v.BaselineMs = BaselineMs ;
  v.WaitAvgMs = WaitAvgMs ;
  v.WaitMaxProb = WaitMaxProb ;
  v.ReacTimeMinMs = ReacTimeMinMs ;
  v.RespWinWidMs = RespWinWidMs ;
  v.RewardSlope = RewardSlope ;
  v.RewardMinMs = RewardMinMs ;
  v.RewardFailFrac = RewardFailFrac ;
  v.ScreenGamma = ScreenGamma ;
  v.ItiMinMs = ItiMinMs ;
  v.BehaviourXaxis = BehaviourXaxis ;
  v.TdtHostPC = TdtHostPC ;
  v.TdtExperiment = TdtExperiment ;
  v.LaserCtrl = LaserCtrl ;
  v.LaserBuffer = LaserBuffer ;
  v.LaserSwitch = LaserSwitch ;
  v.PowerScaleCoef = PowerScaleCoef ;
  v.NumLaserChanOut = NumLaserChanOut ;
  v.TdtChannels = TdtChannels ;
  v.SpikeBuffer = SpikeBuffer ;
  v.MuaStartIndex = MuaStartIndex ;
  v.MuaBuffer = MuaBuffer ;
  v.LfpStartIndex = LfpStartIndex ;
  v.LfpBuffer = LfpBuffer ;
  v.StimRespSim = StimRespSim ;
  
  % These variables must be integers
  INTARG = { 'NumLaserChanOut' , 'TdtChannels' , 'MuaStartIndex' , ...
    'LfpStartIndex' } ;
  
  % These variables are case invariant. Make sure that corresponding set of
  % valid strings (lim, above) is lower case.
  CASEINV = { 'TrainingMode' } ;
  
  % Numeric variables
  for  N = fieldnames( v )' ; n = N{ 1 } ;
    
    % Empty field signals that we skip checks on these vars
    if  isempty( lim.( n ) )
      
      continue
      
    % Check type. First see if variable is expected to be Text
    elseif  iscellstr( lim.( n ) )
      
      % Check that variable is string
      if  ~ ischar( v.( n ) )  ||  ~ isrow( v.( n ) )
        error( '%s must be a char row vector i.e. a string' , n )
      end
      
      % Make sure that string is lower case for case invariant variables
      if  any( strcmp( n , CASEINV ) ) , v.( n ) = lower( v.( n ) ) ; end
      
      % String not found in set of valid strings. Don't kill session. But
      % do warn user.
      if  ~ any( strcmp( v.( n ) , lim.( n ) ) )
        
        % Format the warning string
        wstr = sprintf( '%s must be one of: %s' , ...
          n , strjoin( lim.( n ) , ', ' ) ) ;
        
        % Print in both echo server window, the command window, and error
        % log
        EchoServer.Write( wstr )
        warning( wstr )
        
      end % invalid string
      
    % All remaining variables must be of double numeric type
    elseif  ~ isa( v.( n ) , 'double' )
      
      error( '%s must be of type double' , n )
      
    % Check numeric variable is within acceptable limits
    elseif  v.( n ) < lim.( n )( 1 )  ||  v.( n ) > lim.( n )( 2 )
      
      error( '%s must be within inclusive range [ %.3f , %.3f ]' , ...
        n , lim.( n ) )
      
    % Check integer args
    elseif  any( strcmp( n , INTARG ) )  &&  mod( v.( n ) , 1 )
      
      error( '%s must be an integer' , n , lim.( n ) )
      
    end % checks
    
  end % num vars
  
end % evarchk

