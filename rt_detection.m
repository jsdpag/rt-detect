
% 
% rt_detection.m
% 
% Use Win32 Start/EndFix, Start/EndSacc events from EyeLinkServer to
% control the timing on states in this training version of the reaction
% time detection task used by Jackson Smith's optogenetics project in the
% lab of Pascal Fries.
% 
% Total power = LaserMaxPowerPerChan_mW * PowerScaleCoef * NumLaserChanOut
% 


%%% GLOBAL INITIALISATION %%%

% Session's ARCADE config object
cfg = retrieveConfig ;

% Error log message marking start of task script operations
logmessage( sprintf( 'Task script rt_detection.m PREP trial %d, %s' , ...
  TrialData.currentTrial , cfg.sessionName ) )

% Gain access to block selection function's global variable and also task
% script shutdown tasks
global  ARCADE_BLOCK_SELECTION_GLOBAL ;
global  ARCADE_TASK_SCRIPT_SHUTDOWN   ;

% Condition, block, outcome and reaction time of all previous trials
pre = getPreviousTrialData ;

% Error check editable variables
v = evarchk( RewardMaxMs , RfXDeg , RfYDeg , RfRadDeg , RfAngleDeg , ...
      RfWinFactor , TargetTimeMs , RfTargetFactor , FixTolDeg , ...
      TrainingMode , BaselineMs , WaitAvgMs , WaitMaxProb , ...
      ReacTimeMinMs , RespWinWidMs , RewardSlope , RewardMinMs , ...
      RewardFailFrac , ScreenGamma , ItiMinMs , BehaviourXaxis , ...
      TdtHostPC , TdtExperiment , LaserCtrl , LaserBuffer , LaserSwitch,...
      PowerScaleCoef , NumLaserChanOut , TdtChannels , BufBaselineMs , ...
      SpikeBuffer , MuaStartIndex , MuaBuffer , LfpStartIndex , ...
      LfpBuffer , StimRespSim ) ;

% Properties of current trial condition. Used in 'Stimulus configuration'.
c = table2struct(  ...
  ARCADE_BLOCK_SELECTION_GLOBAL.tab( TrialData.currentCondition == ...
    ARCADE_BLOCK_SELECTION_GLOBAL.tab.Condition , : )  ) ;


%%% TRIAL INITIALISATION -- PERSISTENT DATA %%%

% First trial of session
if  TrialData.currentTrial == 1
  
  % Extra toolboxes required by this task
  PATHS = { 'TDTMatlabSDK' , 'mak' , 'laser-signals' , ...
            'tdt-windowed-buffering' } ;
  GENPAT = { 'TDTMatlabSDK' } ;

  % Toolboxes , get absolute path
  for  TB = PATHS , tb = [ 'C:\Toolbox\' , TB{ 1 } ] ;
    
    % Cannot find Toolbox, report error to user
    if  ~ exist( tb , 'dir' ), error( 'Cannot find Toolbox: %s' , tb ), end
    
    % Expand recursively into toolbox sub-directories
    if  any( strcmp( TB{ 1 } , GENPAT ) ) , tb = genpath( tb ) ; end
    
    % Add to path
    addpath( tb )
    
  end % toolboxes
  
  % Define task script shutdown tasks. ITI stimulus is always at index 1.
  ARCADE_TASK_SCRIPT_SHUTDOWN = cell( 1 , 12 ) ;
  
  % Store local pointer to table defining blocks of trials
  P.tab = ARCADE_BLOCK_SELECTION_GLOBAL.tab ;
  
    % Contrast string regular expression
    P.constrreg = '(?<=con)([01]?(\.\d+)?)' ;
  
    % Task-specific validity tests on block definition table
    P.tab = tabvalchk( P.tab , P.constrreg ) ;
    
    % Are there any trial conditions that mirror the target?
    P.mirror = any( strcmp( P.tab.Mirror , 'on' ) ) ;
  
  % Handle to session's behavioural store object
  P.bhv = SGLBehaviouralStore.launch ;
  
  % Define state names, column of cells
  P.nam = { 'Start' , 'HoldFix' , 'Wait' , 'TargetOn' , ...
    'ResponseWindow' , 'Saccade' , 'GetSaccadeTarget' , 'Evaluate' , ...
      'TargetSelected' , 'Microsaccade' , 'NothingSelected' , 'GetFix' ,...
        'FalseAlarmSaccade' , 'Ignored' , 'Blink' , 'BrokenFix' , ...
          'BrokenSaccade' , 'EyeTrackError' , 'FalseAlarm' , 'Missed' , ...
            'Failed' , 'Correct' , 'cleanUp' }' ;
  
  % Event marker codes for each state
  [ P.evm , P.evh ] = event_marker( P.nam ) ;
  
  % Make copy of trial error name to value mapping
  P.err = ARCADE_BLOCK_SELECTION_GLOBAL.err ;
  
  % Open Win32 inter-process communication events
  for  E = { 'StartSacc' , 'EndSacc' , 'StartFix' , 'FalseAlarmFlag' , ...
      'Waiting' , 'BlinkStart' , 'BlinkEnd' }
    name = E{ 1 } ;
    P.( name ) = IPCEvent( name ) ;
  end
  
  % Get screen parameters
  P.framerate = double( round( StimServer.GetFrameRate ) ) ;
  P.screensize = double( StimServer.GetScreenSize ) ;
  
  % Calculate pixels per degree of visual field. cm/deg * pix/cm = pix/deg.
  P.pixperdeg = ( cfg.DistanceToScreen * tand( 1 ) )  *  ...
    ( sqrt( sum( P.screensize .^ 2 ) ) / cfg.MonitorDiagonalSize ) ;
  
    % Rectify this wrong
    cfg.PixelsPerDegree = P.pixperdeg ;
  
  % Screen size in degrees
  P.screendegs = P.screensize ./ P.pixperdeg ;
  
  % Previous trial eye track window parameters
  P.EyeTrack = struct( 'RfXDeg' , NaN , 'RfYDeg' , NaN , ...
    'RfRadDeg' , NaN , 'RfWinFactor' , NaN , 'FixTolDeg' , NaN ) ;
  
  % Create flicker objects
  P.Flicker.stim = Rectangle ;
  P.Flicker.anim =   Flicker ;
  
    % Certain properties are fixed
    P.Flicker.stim.faceColor( : ) = double( intmax( 'uint8' ) ) ;
    P.Flicker.stim.width  = P.screensize( 1 ) ;
    P.Flicker.stim.height = P.screensize( 2 ) ;
    
    % Kill objects at session end
    ARCADE_TASK_SCRIPT_SHUTDOWN{ 2 } = @( ) delete( P.Flicker.stim ) ;
    ARCADE_TASK_SCRIPT_SHUTDOWN{ 3 } = @( ) delete( P.Flicker.anim ) ;
  
  % Create target stimulus objects, a bit of trickery required to create an
  % empty Stimulus object for 'none'.
  P.Target.bar      = Rectangle ;
  P.Target.circle   = Circle ;
  P.Target.gaussian = Gaussian ;
  P.Target.none     = P.Target.gaussian( [ ] ) ;
  P.Target.anim     = Flash ;
  
    % Bar height i.e. thickness is fixed at the same default value as in
    % bar_mapping_cfg.mat of the bar.mapping ARCADE task repository
    P.Target.bar.height = 0.125 * P.pixperdeg ;
    
    % Fix animation terminal actions. Stop painting stimulus. And flip
    % value of photodiode square. Beware, target 'visible' property is not
    % changed.
    P.Target.anim.terminalAction = '00000101' ;
    
    % Kill objects at session end
    ARCADE_TASK_SCRIPT_SHUTDOWN{ 4 } = @( ) delete( P.Target.bar      ) ;
    ARCADE_TASK_SCRIPT_SHUTDOWN{ 5 } = @( ) delete( P.Target.circle   ) ;
    ARCADE_TASK_SCRIPT_SHUTDOWN{ 6 } = @( ) delete( P.Target.gaussian ) ;
    ARCADE_TASK_SCRIPT_SHUTDOWN{ 7 } = @( ) delete( P.Target.anim     ) ;
  
  % Create fixation point mask, so that the point is stable during flicker
  P.FixMask = Circle ;
  
    P.FixMask.faceColor( : ) = cfg.BackgroundRGB ;
    P.FixMask.diameter = 0.5 * P.pixperdeg ;
    ARCADE_TASK_SCRIPT_SHUTDOWN{ 8 } = @( ) delete( P.FixMask ) ;
    
  % Create gaze fixation stimulus
  P.Fix = Rectangle ;
  
    % Parameters are fixed
    P.Fix.position = [ 0 , 0 ] ;
    P.Fix.faceColor( : ) = 255 ;
    P.Fix.lineColor( : ) = 255 ;
    P.Fix.lineWidth = 1 ;
    P.Fix.drawMode = 3 ;
    P.Fix.width = sqrt( pi * 0.075 ^ 2 ) * P.pixperdeg ;
    P.Fix.height = P.Fix.width ;
    P.Fix.angle = 45 ;
    ARCADE_TASK_SCRIPT_SHUTDOWN{ 9 } = @( ) delete( P.Fix ) ;
    
    % Base mask values on fixation point
    P.FixMask.position = P.Fix.position ;
  
  % Look for set of Mondrian mask files
  P.Mondrian.files = dir( 'C:\Toolbox\Mondrian\*png' ) ;
  
    % No files found
    if  isempty( P.Mondrian.files )
      error( 'No ITI Mondrian masks found in C:\Toolbox\Mondrian\*png' )
    end
    
  % Initialise inter-trial-interval stimulus handle pointers
  P.ItiStim.current  = [ ] ;
  P.ItiStim.previous = [ ] ;
  
  % Make reaction time start and end time variables, and tic time
  % measurement at end of previous trial for ITI measure as well as end of
  % Wait state to check against window buffer timer duration.
  P.RTstart  = StateRuntimeVariable ;
  P.RTend    = StateRuntimeVariable ;
  P.ITIstart = StateRuntimeVariable ;
  P.WaitEnd  = StateRuntimeVariable ;
  
    % Initialise P.ITIstart to zero, so that we don't wait on first trial
    P.ITIstart.value = zeros( 1 , 'uint64' ) ;
     P.WaitEnd.value = zeros( 1 , 'uint64' ) ;
  
  % Create and initialise behaviour plots
  P.bfig = creatbehavfig( cfg , P.err , P.tab , BehaviourXaxis , false ) ;

  % Initialise connection to Synapse server on TDT HostPC
  P.syn = initsynapse( cfg , P.tab , P.evm , P.err , TdtHostPC , ...
    TdtExperiment , LaserCtrl , LaserBuffer , LaserSwitch , SpikeBuffer,...
      MuaBuffer , LfpBuffer , StimRespSim ) ;

    % Create a logical flag that is raised when synapse is in use
    P.UsingSynapse = ~ isempty( P.syn ) ;
    
  % Set up SynapseAPI environment if available
  if  P.UsingSynapse
    
    % Send end of session message
    footer = [ 'ARCADE end session ' , cfg.sessionName ] ;
    ARCADE_TASK_SCRIPT_SHUTDOWN{ 10 } = ...
      @( ) iset( P.syn , 'RecordingNotes' , 'Note' , footer ) ;
    
    % Drop Synapse to Idle mode
    ARCADE_TASK_SCRIPT_SHUTDOWN{ 11 } = @( ) P.syn.setModeStr( 'Idle' ) ;
    
    % Load up inverse laser transfer functions
    P.invtrans = getlasercoefs( cfg , 'laser_coefs.mat' ) ;
    
    % Create a LaserController MATLAB object for setting parameter values
    % of the named LaserController Gizmo
    P.laserctrl = LaserController( P.syn , LaserCtrl ) ;

      % Set fixed parameters for remainder of bar mapping session
      P.laserctrl.EventIntOn = P.evm.TargetOn_entry ;
      P.laserctrl.EventIntReset = P.evm.cleanUp_entry ;
      P.laserctrl.EventIntRstOpt = P.evm.Saccade_entry ;
      P.laserctrl.UseLaser = false ;
      P.laserctrl.UsePhotodiode = false ;
      P.laserctrl.PhotodiodeThreshold = 0.67 ;
      P.laserctrl.PhotodiodeDirectionStr = 'falling' ;
      P.laserctrl.PhotodiodeTimeLow = 4 ;
      P.laserctrl.Enablemanual = false ;

    % Create LaserSignalBuffer MATLAB object for setting parameter values
    % of the named LaserSignalBuffer. Critically, this object loads the
    % laser's voltage input signal into a TDT memory buffer, for triggered
    % playback.
    P.laserbuff = LaserSignalBuffer( P.syn , LaserBuffer ) ;
    
      % Attempt to use 1000Hz output sampling rate
      P.laserbuff.FsTarget = 1e3 ;
    
    % Pre-allocate empty arrays for buffers
    P.buf = struct( 'spk' , [ ] , 'mua' , [ ] , 'lfp' , [ ] ) ;
    
    % Raise flags when buffer Gizmo name is other than 'none'
    P.flg.spk = ~ strcmpi( SpikeBuffer , 'none' ) ;
    P.flg.mua = ~ strcmpi(   MuaBuffer , 'none' ) ;
    P.flg.lfp = ~ strcmpi(   LfpBuffer , 'none' ) ;
    
    % MUA and LFP signals are in the different buffer Gizmos
    P.buf.difmualfp = ~ strcmp( MuaBuffer , LfpBuffer ) ;
    
    % Create triggered buffer MATLAB objects
    if  P.flg.spk , P.buf.spk = TdtWinBuf( P.syn , SpikeBuffer ) ; end
    if  P.flg.mua , P.buf.mua = TdtWinBuf( P.syn ,   MuaBuffer ) ; end
    if  P.flg.lfp
      if  P.buf.difmualfp
        P.buf.lfp = TdtWinBuf( P.syn , LfpBuffer ) ;
      else
        P.buf.lfp = P.buf.mua ;
      end
    end
    
      %- Set fixed buffer parameters -%

      % We add this many milliseconds to the start and end of the buffers,
      % to make sure that we grab the data that we want
      P.extratime = 25 ;
      
      % Buffer size grabs a baseline window that ends the moment the
      % laser is triggered. Then adds a window following the onset of the
      % laser signal that ends at the same time point as the response
      % window i.e. the latest allowable saccade onset time.
      secs = ( BufBaselineMs  +  ReacTimeMinMs  +  RespWinWidMs  +  ...
        2 * P.extratime ) / 1e3 ;

      % For spike buffer, assume no unit will generate above 1000spk/sec.
      if  P.flg.spk , P.buf.spk.setbufsiz( secs , 1000 ) ; end
      if  P.flg.mua , P.buf.mua.setbufsiz( secs )        ; end
      if  P.flg.lfp && P.buf.difmualfp , P.buf.lfp.setbufsiz( secs ) ; end

      % Response window contains only time of laser onset to last allowable
      % reaction time i.e. saccade onset
      secs = ( ReacTimeMinMs  +  RespWinWidMs  +  P.extratime ) / 1e3 ;

      % Again, assume no spike rate above 1000spk/sec
      if  P.flg.spk , P.buf.spk.setrespwin( secs , 1000 ) ; end
      if  P.flg.mua , P.buf.mua.setrespwin( secs )        ; end
      if  P.flg.lfp && P.buf.difmualfp , P.buf.lfp.setrespwin( secs ) ; end
      
      % Max buffer Gizmo response window timer duration in seconds
      P.maxtimerddur = secs ;
      
      % Maximum number of channels to return following each buffer read
      if  P.flg.spk , P.buf.spk.setchsubsel( TdtChannels ) ; end
      
        % Number of channels to return from MUA/LFP buffer(s). This changes
        % depending on whether both data types have the same buffer or not.
        tdtchan = ...
          max( [ MuaStartIndex , LfpStartIndex ]  +  TdtChannels  -  1 ) ;
      
        % Always assign to MUA buffer, conditionally to LFP buffer
        if  P.flg.mua , P.buf.mua.setchsubsel( tdtchan ) ; end
        if  P.flg.lfp && P.buf.difmualfp, P.buf.lfp.setchsubsel( tdtchan );
        end

      % Crop buffered data in specified time window around trigger event.
      % Include a few extra milliseconds so that MUA interpolation by
      % onlinefigure does not return NaN.
      secs = [ -BufBaselineMs - P.extratime , ...
               +ReacTimeMinMs + RespWinWidMs + P.extratime ] / 1e3 ;
      if  P.flg.spk , P.buf.spk.settimewin( secs ) ; end
      if  P.flg.mua , P.buf.mua.settimewin( secs ) ; end
      if  P.flg.lfp && P.buf.difmualfp , P.buf.lfp.settimewin( secs ) ; end

    % Simulated ephys signal modulation via FB128 Sync line is enabled
    P.simresp = ~ strcmpi( StimRespSim , 'none' ) ;

      % Set up StimRespSim Gizmo
      if  P.simresp

        % Try to enable the FB128 sync line
        iset( P.syn , StimRespSim , 'Enable' , 1 )

        % Default increased response to full duration of laser signal
        iset( P.syn , StimRespSim , ...
           'LatencyMs' , 0 )
        iset( P.syn , StimRespSim , ...
          'ResponseMs' , ReacTimeMinMs + RespWinWidMs )
        
        % Get min, max, and range of behav plot x-axis variable
        P.xmin = min( P.tab.( BehaviourXaxis ) ) ;
        P.xmax = max( P.tab.( BehaviourXaxis ) ) ;
        P.xrng = P.xmax - P.xmin ;

      else

        % Try to disable the FB128 sync line
        iset( P.syn , StimRespSim , 'Enable' , 0 )

      end % set StimRespSim Giz

    % Create and initialise electrophysiology plots
    [ P.efig , P.chlst ] = createphysfig( cfg , v , P.tab , P.buf ) ;
    
  end % synapse api actions
  
  % Try to guarantee that user has time to look at online plots
  ARCADE_TASK_SCRIPT_SHUTDOWN{ 12 } = @( ) waitfor( msgbox( ...
    [ '\fontsize{14.123}Examine plots.', newline, 'Hit OK when done.' ],...
      'rt_detection.m', 'none', struct( 'WindowStyle', 'non-modal', ...
        'Interpreter' , 'tex' ) ) ) ;
      
  % Remove empty elements
  ARCADE_TASK_SCRIPT_SHUTDOWN( ...
    cellfun( @isempty , ARCADE_TASK_SCRIPT_SHUTDOWN ) ) = [ ] ;
  
% All subsequent trials
else
  
  % Retrieve persistent data
  P = persist ;
  
  % Trial condition table row from previous trial
  cpre = table2struct(  P.tab( pre.conditions( end - 1 ) == ...
    P.tab.Condition , : )  ) ; 
  
  %-- Update behaviour plots based on previous trial --%
  
    %- Behavioural outcome raster plot -%
    newdata = struct( 'pre_err', pre.trialError( end - 1 ), ...
      'pre_block', pre.blocks( end - 1 ), 'nex_block', pre.blocks( end ) );
    
    P.bfig.update( 'BehavRaster' , [ ] , newdata )
    
    %- Trial info panel -%
    newdata = struct( 'ind' , TrialData.currentTrial - [ 1 , 0 ] , ...
      'err' , pre.trialError( end - [ 1 , 0 ] ) , ...
      'con' , pre.conditions( end - [ 1 , 0 ] ) , ...
      'blk' , pre.blocks( end - [ 1 , 0 ] ) , ...
       'rt' , pre.reactionTime( end - [ 1 , 0 ] ) , ...
      'typ' , [ pre.userVariable{ end - 1 }.BlockType , ...
        ARCADE_BLOCK_SELECTION_GLOBAL.typ ] , ...
      'trials' , ARCADE_BLOCK_SELECTION_GLOBAL.count.trials , ...
      'total' , ARCADE_BLOCK_SELECTION_GLOBAL.count.total ) ;
    
    P.bfig.update( 'TrialInfo' , [ ] , newdata )
    
    %- Psychometric and reaction time curves -%
    for  F = { 'Psychometric' , 'Reaction Time' } , f = F{ 1 } ;
      
      % There is no RT in fixation mode
      if  WaitAvgMs == 0 && strcmp( f , 'Reaction Time' ) , continue , end
      
      % Construct graphics object group identifier
      id = sprintf( '%s Block %d %s %s' , f , ...
        pre.userVariable{ end - 1 }.BlockType , cpre.Target , cpre.Laser );
      
      % Information required to update plots
      index = struct( 'x' , P.tab.( BehaviourXaxis )( P.tab.Condition ==...
        pre.conditions( end - 1 ) ) , 'err' , pre.trialError( end - 1 ) ) ;
      newdata = pre.reactionTime( end - 1 ) ;
      
      % Update empirical data and find least-squares best fit
      P.bfig.update( id , index , newdata )
      P.bfig.fit( id )
      
    end % psych & RT curves
    
    %- Reaction time histogram -%
    
    % Construct group id
    id = sprintf( 'RT Block %d' , pre.userVariable{ end - 1 }.BlockType ) ;
    
    % Update histogram, unless we are in fixation mode
    index = pre.reactionTime( end - 1 ) ;
    newdata = pre.trialError( end - 1 ) ;
    if  WaitAvgMs > 0
      P.bfig.update( id , index , newdata )
    end
    
    % Select groups for new block %
    if  diff( pre.blocks( end - [ 1 , 0 ] ) )
      id = sprintf( 'Block %d' , ARCADE_BLOCK_SELECTION_GLOBAL.typ ) ;
      P.bfig.select( 'set' , id )
    end
    
  %-- Update electrophysiology plots based on previous trial --%
  
    % Using synapse
    if  P.UsingSynapse  &&  ~ isempty( P.efig )

      % Select groups for new block, using id from behaviour set selection
      if  diff( pre.blocks( end - [ 1 , 0 ] ) )
        P.efig.select( 'set' , id )
      end

      % Trial was correct or failed so update ephys plots
      if  ( pre.trialError( end - 1 ) == P.err.Correct || ...
                            pre.trialError( end - 1 ) == P.err.Failed )
        
        % Guarantee that buffer Gizmo timers run down.
        sleep( 1e3 * ( P.maxtimerddur - toc( P.WaitEnd.value ) ) )
        
        % Retrieve buffered data
        if  P.flg.spk , P.buf.spk.getdata( ) ; end
        if  P.flg.mua , P.buf.mua.getdata( ) ; end
        if  P.flg.lfp && P.buf.difmualfp , P.buf.lfp.getdata( ) ; end

        % Id of block type on previous trial
        id = sprintf( 'Block %d' , pre.userVariable{ end - 1 }.BlockType );

        % Build name of graphics group to update
        id = [ id , ' ' , cpre.Target , ' ' , cpre.Laser ] ;

        % Get reaction time, if it exists
        switch  pre.trialError( end - 1 )
          case  P.err.Correct , rt = pre.reactionTime( end - 1 ) ;
          case  P.err.Failed  , rt = [ ] ;
        end

        % Update plots
        P.efig.update( id , [ ] , rt )

        % Refresh graphics objects for named group
        P.chlst.Callback( P.chlst , [ ] , id ) ;

      end % correct/failed
    end % update ephys plot
    
end % trial init

%- Show changes to plots -%
drawnow


%%% Trial variables %%%

% Record pixels per degree, computed locally
v.pixperdeg = P.pixperdeg ;

% Add type of block
v.BlockType = ARCADE_BLOCK_SELECTION_GLOBAL.typ ;

% In training mode, we randomly sample the target location and size. This
% will affect the value of the relevant editable variables.
switch  TrainingMode
  
  % Training mode is disabled, do not sample target parameters
  case    'off' , sampletarg = false ;
    
  % Sample on every trial
  case  'trial' , sampletarg =  true ;
    
  % Sample only on first trial of a new block
  case  'block' , sampletarg = TrialData.currentTrial == 1  ||  ...
                               pre.blocks( end - 1 ) ~= pre.blocks( end ) ;
    
  % evarchk should screen this out. If not then it is incorrect.
  otherwise , warning( 'Invalid TrainingMode string: %s' , TrainingMode )
              sampletarg = false ;
end % eval TrainingMode

% Sample target position and update the value of editable variables
if  sampletarg , [ v, RfXDeg, RfYDeg, RfRadDeg ] = newtarget( P , v ) ; end

% Convert variables with degrees into pixels, without destroying original
% value in degrees
for  F = { 'RfXDeg' , 'RfYDeg' , 'RfRadDeg' , 'FixTolDeg' } ; f = F{ 1 } ;
  
  vpix.( f ) = v.( f ) * P.pixperdeg ;
  
end % deg2pix

% Sample wait duration if WaitAvgMs is non-zero.
if  WaitAvgMs > 0
  WaitMs = min( exprnd( WaitAvgMs ) , expinv( WaitMaxProb , WaitAvgMs ) ) ;
else
  WaitMs = 0 ; % Default if WaitAvgMs is zero.
end

  % Make a copy of this trial's waiting time, minus baseline
  v.WaitMs = WaitMs ;

% Compute reward size for correct performance if WaitAvgMs non-zero
if  WaitAvgMs > 0
  rew = rewardsize( P.err.Correct , ...
    expcdf( WaitMs , WaitAvgMs ) / WaitMaxProb , RewardSlope , ...
      RewardMinMs , RewardMaxMs );
else
  rew = RewardMaxMs ; % Default if WaitAvgMs is zero.
end
  
  % And for failed trial [ correct reward , failed reward ]
  rew = [ rew , RewardFailFrac * rew ] ;
  
  % Round up to next millisecond and guarantee minimum reward size
  rew = max( RewardMinMs , ceil( rew ) ) ;
  
  % Store reward sizes
  v.Reward_Correct = rew( 1 ) ;
  v.Reward_Failed  = rew( 2 ) ;
  
% Add baseline period, this is now the duration of the Wait state.
WaitMs = WaitMs  +  BaselineMs ;

% Ask StimServer.exe to apply a measure of luminance Gamma correction
StimServer.InvertGammaCorrection( ScreenGamma ) ;


%%% Eye Tracking %%%

% Check to see if any eye tracking window params have changed since last
% trial, because editable variables were changed during task pause. Don't
% reset and rebuild windows if unnecessary because trackeye wastes 500ms on
% each reset (as of ARCADE v2.6).
if  ~ all(  cellfun( @( f ) v.( f ) == P.EyeTrack.( f ) , ...
                                              fieldnames( P.EyeTrack ) )  )

  % Delete any existing eye window
  trackeye( 'reset' ) ;

  % Create fixation and target eye windows
  trackeye( [ 0 , 0 ] , vpix.FixTolDeg , 'Fix' ) ;
  trackeye( [ vpix.RfXDeg , vpix.RfYDeg ] , vpix.RfRadDeg * RfWinFactor,...
    'Target' ) ;
  
  % Mirrored target position is used, so make a corresponding window
  if  P.mirror
    trackeye( -[ vpix.RfXDeg , vpix.RfYDeg ] , ...
      vpix.RfRadDeg * RfWinFactor , 'Mirror' ) ;
  end
  
  % Remember new values
  for  F = fieldnames( P.EyeTrack )' , f = F{ 1 } ;
    P.EyeTrack.( f ) = v.( f ) ;
  end

end % update eye windows

% Evaluate target mirroring. If mirror is on then the target is reflected
% across the fixation point. Make sure that the correct eye window is used
% to evaluate behaviour.
switch  c.Mirror
  case   'on' , TargetIn = 'MirrorIn' ;
  case  'off' , TargetIn = 'TargetIn' ;
  otherwise , error( 'Invalid Mirror value: %s' , c.Mirror )
end


%%% Visual stimulation parameters %%%

% Reset flicker colour
P.Flicker.stim.faceColor( : ) = double( intmax( 'uint8' ) ) ;

% Determine screen background colour during Wait state
switch  c.WaitBackground
  case  'default' , WaitBak = { 'Background' ,   cfg.BackgroundRGB } ;
  case    'black' , WaitBak = { 'Background' , [ 000 , 000 , 000 ] } ;
  case      'red' , WaitBak = { 'Background' , [ 255 , 000 , 000 ] } ;
  otherwise
    
    % Attempt to read background contrast
    bakcon = regexp( c.WaitBackground , P.constrreg , 'tokens' , 'once' ) ;
    
    % Check for contrast
    if  ~ isempty( bakcon )
      
      % regexp returns { <string> }, convert string to numeric
      bakcon = str2double( bakcon{ 1 } ) ;
      
      % Convert from Michelson contrast into pixel delta
      bakcon = bakcon .* cfg.BackgroundRGB ;
      
      % Set background ...
      WaitBak = { 'Background' , max( 0 , cfg.BackgroundRGB - bakcon ) } ;
      
      % ... and flicker colours
      P.Flicker.stim.faceColor( : ) = ...
        min( double( intmax( 'uint8' ) ) , cfg.BackgroundRGB + bakcon ) ;
    
    % No recognisable contrast or valid background colour provided
    else , error( 'Unrecognised Wait background: %s', c.WaitBackground )
    end
    
end % background colour

% Background flicker
if  c.BackgroundFlickerHz
  
  % Determine number of frames per cycle. Divided by 2. One half of frames
  % ON, the other half, OFF.
  n = P.framerate  /  c.BackgroundFlickerHz  /  2 ;
  
  % There is a fractional component, so round up to next whole frame
  if  mod( n , 1 ) , n = ceil( n ) ; end
  
  % Set flicker animation object parameters
  P.Flicker.anim.SetFrames( n , n ) ;
  
  % Bind animation to background rectangle
  P.Flicker.stim.play_animation( P.Flicker.anim ) ;
  
  % Point to background rectangle
  BackFlic = P.Flicker.stim ;
  
  % Enable fixation point mask
  FixMask = P.FixMask ;
  
% No background flicker , point to empty stimulus and fix point mask
else , BackFlic = P.Target.none ; FixMask = P.Target.none ;
end

% Apply optional reflection of target position across fixation point. This
% coefficient can be multiplied into the set target location. mirror is +1
% if mirror is off, and it is -1 if the mirror is on.
mirror = strcmp( c.Mirror , 'off' ) - strcmp( c.Mirror , 'on' ) ;

% Point to specified target
Target = P.Target.( c.Target ) ;

  % Configure target stimulus for upcoming trial, according to type
  switch  c.Target
    
    case  'none' % no action required
        
    case  'bar'
      
      Target.position = mirror .* [ vpix.RfXDeg , vpix.RfYDeg ] ;
      Target.width = 2 * vpix.RfRadDeg * RfTargetFactor ;
      Target.angle = RfAngleDeg ;
      Target.faceColor( : ) = Weber( c.Contrast , WaitBak{ 2 } ) ;
      
    case  'circle'
      
      Target.position = mirror .* [ vpix.RfXDeg , vpix.RfYDeg ] ;
      Target.diameter = 2 * vpix.RfRadDeg * RfTargetFactor ;
      Target.faceColor( : ) = Weber( c.Contrast , WaitBak{ 2 } ) ;
      
    case  'gaussian'
      
      Target.position = mirror .* [ vpix.RfXDeg , vpix.RfYDeg ] ;
      Target.sdx = vpix.RfRadDeg * RfTargetFactor ;
      Target.sdy = Target.sdx ;
      Target.angle = RfAngleDeg ;
      Target.color( : ) = Weber( c.Contrast , WaitBak{ 2 } ) ;
      
    otherwise , error( 'Unrecognised target stimulus: %s' , c.Target )
      
  end % config targ stim
  
  % There is a visual target
  if  ~ strcmp( c.Target , 'none' )
    
    % Non-zero target time specified, TargetTimeFrames holds temp value
    if  TargetTimeMs
      
      TargetTimeFrames = TargetTimeMs ;
      
    % Match the flash duration to the longest possible reaction time
    elseif  TargetTimeMs == 0
      
      TargetTimeFrames = ReacTimeMinMs + RespWinWidMs ;
      
    % We should never get here
    else , error( 'Programming error, TargetTimeMs' ) 
    end
    
    % Convert from ms to frames
    TargetTimeFrames = ceil( TargetTimeFrames / 1e3 * P.framerate ) ;
    
    % Assign number of frames to target flash animation
    P.Target.anim.nFrames = TargetTimeFrames ;
    
    % Re-assign animation to stimulus object
    Target.play_animation( P.Target.anim ) ;
    
  end % flash
  
  % Synapse is in use
  if  P.UsingSynapse
    
    % Set behaviour of laser controller based on visual target type
    switch  c.Target
      
      % No target, so ignore the photodiode
      case  'none' , P.laserctrl.UsePhotodiode = false ;
        
      % Visual target enabled, so syncronise with photodiode
      otherwise    , P.laserctrl.UsePhotodiode =  true ;
    end
  end % using synapse
  
% Inter-trial stimulus' handle pointer swap. Previous trials's stimulus is
% currently being presented, and will be destroyed at the end of the inter-
% trial-interval that is now being executed.
P.ItiStim.previous = P.ItiStim.current ;

% Inter-trial stimulus to be presented at the end of the upcoming trial
switch  c.ItiStimulus
  
  % Empty Stimulus object
  case  'none' , P.ItiStim.current = P.Target.none ;
                 ARCADE_TASK_SCRIPT_SHUTDOWN{ 1 } = @( ) [ ] ;
    
  % Randomly selected Mondrian mask
  case  'mondrian'
    
    % Random draw
    i = ceil( rand * numel( P.Mondrian.files ) ) ;
    
    % Create Picture object to display this file on screen
    P.ItiStim.current = Picture( fullfile( P.Mondrian.files( i ).folder,...
      P.Mondrian.files( i ).name ) ) ;
    
    ARCADE_TASK_SCRIPT_SHUTDOWN{ 1 } = @( ) delete( P.ItiStim.current ) ;
    
  otherwise , error( 'Unrecognised ITI stimulus: %s' , c.ItiStimulus )
end


%%% Laser stimulation parameters %%%

% No connection to TDT Synapse, do nothing
if  ~ P.UsingSynapse
  
  % No action required

% We are connected to TDT Synapse and a laser is required on next trial
elseif  P.UsingSynapse  &&  ~ strcmp( c.Laser , 'none' )
  
  % Gen inverse transfer function for laser in next trial condition
  itran = P.invtrans.( c.Laser ) ;
  
  % Compute max power that rides on top of emission baseline. This is the
  % total power required from the laser to power all laser output channels.
  maxpow = c.LaserMaxPowerPerChan_mW * PowerScaleCoef * NumLaserChanOut ;
  
  % Cap at maximum measured power output
  maxpow = min( maxpow , itran.max_power_mW ) ;
  
  % Subtract emission baseline
  maxpow = maxpow - itran.min_power_mW ;
  
  % Number of complete voltage output samples by end of max response window
  N = ...
    floor( P.laserbuff.FsSignal * ( ReacTimeMinMs + RespWinWidMs ) / 1e3 );
  
  % Laser frequency is zero means constant value, return ones for scaling
  if  c.LaserFreqHz == 0
    
    X = ones( 1 , N ) ;
    
  % Non-zero frequency, make sine wave peaking at [0,1] for scaling
  else
    
    % Time vector spanning laser signal
    X = ( 1 : N ) ./ P.laserbuff.FsSignal ;
    
    % Convert phase from degrees to radians
    phi = pi / 180 * c.LaserPhaseDeg ;
    
    % Sine wave
    X = sin( 2 * pi * c.LaserFreqHz .* X  +  phi ) / 2  +  0.5 ;
    
  end % scalable laser signal
  
  % Apply envelope
  switch  c.LaserEnvelope
    
    % No envelope, no action
    case  'none'
      
    % Increasing linear envelope
    case  'linear+' , X = ( 1 : N ) ./ N  .*  X ;
    
    % Uniformly distributed random noise
    case  'uniform' , X = rand( 1 , N ) .* X ; 
      
    % We should not ever get here
    otherwise , error( 'LaserEnvelope programming error.' )
      
  end % envelope
  
  % Scale and shift the signal to occupy the entire dynamic range of the
  % laser from baseline emission to maximum set output power
  X = maxpow .* X  +  itran.min_power_mW ;
  
  % LaserSwitch Gizmo channels the control voltage to the correct laser
  iset( P.syn , LaserSwitch , 'Laser' , itran.index )
  
  % Inverse transfer function converts the power output that we want into
  % the voltage that we need to produce the desired output. Loaded into the
  % LaserSignalBuffer Gizmo for triggered playback.
  P.laserbuff.Signal = ppval( itran.piecewise_polynomial.inv , X ) ;
  
  % StimRespSim Gizmo in use
  if  P.simresp
    
    % Enable FB128 sync line according to laser type
    iset( P.syn , StimRespSim , 'Enable' , ...
      double( strcmp( c.Laser , 'test' ) ) )
    
    % Maximum response duration
    MaxDurMs = ReacTimeMinMs + RespWinWidMs ;
    
    % Compute duration of response
    ResponseMs = ( c.( BehaviourXaxis ) - P.xmin ) / P.xrng  *  MaxDurMs ;
    
    % Compute latency to response
    iset( P.syn , StimRespSim , 'LatencyMs' , MaxDurMs - ResponseMs )
    
    % Duration of high-state is proportional to x-axis variable
    iset( P.syn , StimRespSim , 'ResponseMs' , ResponseMs )

  end % StimRespSim Gizmo
  
  % Make sure that laser is triggered
  P.laserctrl.UseLaser = true ;
  
% We are connected to TDT Synapse and no laser is needed on next trial
elseif  P.UsingSynapse  &&  strcmp( c.Laser , 'none' )
  
  % Make sure that laser is disabled
  P.laserctrl.UseLaser = false ;
  P.laserbuff.Signal   =     0 ;
  
  % Make sure that FB128 sync line stays low
  if  P.simresp , iset( P.syn , StimRespSim , 'Enable' , 0 ) ; end
  
% We should never get here
else
  
  error( 'Programming error in Laser parameter section.' )
  
end % laser param


%%% DEFINE TASK STATES %%%

% Special actions executed when state is finished executing. Remember to
% make this a column vector of cells.
  
  % Pause briefly to allow the first couple of FIXUPDATE events to stream
  % from EyeLink to EyeLinkServer, which then needs time to adjust Win32
  % events pertaining to target windows
  ENDACT.GetSaccadeTarget = { @( ) sleep( 75 ) } ;

  % Correct state. Calculate reaction time, convert unit from seconds to
  % milliseconds. Report RT.
  ENDACT.Correct = ...
    { @( ) reactiontime( 'writeRT' , 1e3 * ( P.RTend.get_value( ) - ...
             P.RTstart.get_value( ) ) ) ;
      @( ) EchoServer.Write( '%8sRT %dms\n' , '' , ...
             ceil( P.bhv.reactionTime( P.bhv.currentTrial ) ) ) } ;
  
  % cleanUp measures time that inter-trial-interval starts, then prints one
  % final message to show that all State objects have finished executing
  % and that control is returning to ARCADE's inter-trial code.
  ENDACT.cleanUp = ...
    { @( ) P.ITIstart.set_value( tic ) ;
      @( ) EchoServer.Write( 'End trial %d\n' , TrialData.currentTrial ) };
  
  % SynapseAPI is live, send run-time note about end of trial, and
  % guarantee that the windowed buffer Gizmo timers run out before access.
  if  P.UsingSynapse
    ENDACT.Wait = { @( ) P.WaitEnd.set_value( tic ) } ;
    ENDACT.Correct{ end + 1 } = @( ) iset(  P.syn , 'RecordingNotes' , ...
      'Note' , sprintf( 'RT %dms' , ...
        ceil( P.bhv.reactionTime( P.bhv.currentTrial ) ) )  ) ;
    ENDACT.cleanUp{ end + 1 } = @( ) iset( P.syn , 'RecordingNotes' , ...
      'Note' , sprintf( 'End trial %d' , TrialData.currentTrial ) ) ;
  end

% Special constants for value of max reps
MAXREP_DEFAULT = 2 ;
MAXREP_GETFIX  = 100 ;
MAXREP_NEXT = 'BrokenFix' ;

% Table of states. Each row defines a state. Column order is: state name;
% timeout duration; next state after timeout or max repetitions; wait event
% list; next state(s) after wait event(s), latter two are string or cell of
% strings; cell array of additional Name/Value input args for onEntry
% actions. For onEntry args, the State, State event marker, trial error
% code, and time zero state handle are automatically generated; only
% include additional args.
STATE_TABLE = ...
{           'Start' , 5000 , 'Ignored'        ,     'FixIn' , 'HoldFix' , { 'Stim' , { P.Fix } , 'StimProp' , { P.Fix , 'faceColor' , [ 000 , 000 , 000 ] } , 'Photodiode' , 'off' , 'Reset' , P.Waiting } ;
          'HoldFix' ,  300 , 'Wait'           ,    'FixOut' , 'GetFix' , { 'StimProp' , { P.Fix , 'faceColor' , [ 255 , 255 , 255 ] } } ;
             'Wait' ,WaitMs, 'TargetOn'       ,  { 'FixOut' , 'StartSacc' } , { 'BrokenFix' , 'FalseAlarmSaccade' } , [ { 'Reset' , [ P.StartSacc , P.EndSacc , P.BlinkStart , P.BlinkEnd , P.FalseAlarmFlag ] , 'Trigger' , P.Waiting , 'Photodiode' , 'on' , 'Stim' , { FixMask , BackFlic } } , WaitBak ] ;
     'TargetOn' ,ReacTimeMinMs, 'ResponseWindow' ,  { 'FixOut' , 'StartSacc' } , { 'BrokenFix' , 'FalseAlarmSaccade' } , { 'Stim' , { Target } , 'Photodiode' , 'off' , 'RunTimeVal' , P.RTstart } ;
'ResponseWindow', RespWinWidMs, 'Failed'         ,  { 'FixOut' , 'StartSacc' } , { 'BrokenFix' , 'Saccade' } , { 'Reset' , P.Waiting } ;
          'Saccade' ,  125 , 'BrokenSaccade'  ,  { 'BlinkStart' , 'EndSacc' } , { 'Blink' , 'GetSaccadeTarget' } , { 'Reset' , P.StartFix , 'RunTimeVal' , P.RTend } ;
 'GetSaccadeTarget' ,  100 , 'EyeTrackError'  ,  'StartFix' , 'Evaluate' , {} ;
         'Evaluate' ,    0 , 'EyeTrackError'  ,  { TargetIn , 'FixIn' , 'FixOut' } , { 'TargetSelected' , 'Microsaccade' , 'NothingSelected' } , {} ;
   'TargetSelected' ,    0 , 'Correct'        , 'FalseAlarmFlag' , 'FalseAlarm' , {} ;
     'Microsaccade' ,    0 , 'EyeTrackError'  , {} , {} , {} ;
  'NothingSelected' ,    0 , 'Missed'         ,   'Waiting' , 'BrokenFix' , {} ;
           'GetFix' , 5000 , 'Ignored'        ,     'FixIn' , 'HoldFix' , { 'StimProp' , { P.Fix , 'faceColor' , [ 000 , 000 , 000 ] } } ;
'FalseAlarmSaccade' ,    0 , 'Saccade'        , {} , {} , { 'Trigger' , P.FalseAlarmFlag } ;
          'Ignored' ,    0 , 'cleanUp'        , {} , {} , {} ;
            'Blink' , 5000 , 'cleanUp'        , 'BlinkEnd' , 'cleanUp' , {} ;
        'BrokenFix' ,    0 , 'cleanUp'        , {} , {} , {} ;
    'BrokenSaccade' ,    0 , 'cleanUp'        , {} , {} , {} ;
    'EyeTrackError' ,    0 , 'cleanUp'        , {} , {} , {} ; 
       'FalseAlarm' ,    0 , 'cleanUp'        , {} , {} , {} ;
           'Missed' ,    0 , 'cleanUp'        , {} , {} , {} ;
           'Failed' ,    0 , 'cleanUp'        , {} , {} , { 'Reward' , v.Reward_Failed  } ;
          'Correct' ,    0 , 'cleanUp'        , {} , {} , { 'Reward' , v.Reward_Correct } ;
          'cleanUp' ,    0 , 'final'          , {} , {} , { 'Photodiode' , 'off' , 'Background' , cfg.BackgroundRGB , 'Stim' , { P.ItiStim.current } , 'StimProp' , { P.Fix , 'visible' , false , Target , 'visible' , false , BackFlic , 'visible' , false , FixMask , 'visible' , false } } ;
} ;

% Error check first trial, make sure that there is an event marker for
% each state name
if  TrialData.currentTrial == 1 && ~isequal( P.nam , STATE_TABLE( : , 1 ) )
    
  error( 'Mismatched event and state names' )
  
end % state name check

% Special case, the task is in 'fixation mode' because WaitAvgMs is zero
if  WaitAvgMs == 0
  
  % Rewire the state graph. TargetOn times out onto Correct.
  i = strcmp( 'TargetOn' , STATE_TABLE( : , 1 ) ) ;
  STATE_TABLE{ i , 3 } = 'Correct' ;
  
  % In addition, RespWinWidMs is now the duration of TargetOn.
  STATE_TABLE{ i , 2 } = RespWinWidMs ;
  
  % And we remove all RT computations
  ENDACT = rmfield( ENDACT , 'Correct' ) ;
  
end % fixation mode


%%% MAKE ARCADE STATES %%%

% State table rows
for  row = 1 : size( STATE_TABLE , 1 )
  
  % Map table entry to meaningful names
  [ name , timeout , tout_next , waitev , wait_next , entarg ] = ...
    STATE_TABLE{ row , : } ;
  
  % Create new state
  states.( name ) = State( name ) ;
  
  % Set timeout duration, max number executions, and next state after
  % timeout or max reps. Max reps = 2 so that no inf loops, and don't trig
  % wrong state.
  states.( name ).duration                     =        timeout ;
  states.( name ).maxRepetitions               = MAXREP_DEFAULT ;
  states.( name ).nextStateAfterTimeout        =      tout_next ;
  states.( name ).nextStateAfterMaxRepetitions =      tout_next ;
  states.( name ).waitEvents                   =         waitev ;
  states.( name ).nextStateAfterEvent          =      wait_next ;
  
  % Issue a trial error code if this is an end state i.e. it transitions to
  % cleanUp. Default empty.
  TrialError = { } ;
  if  strcmp( tout_next , 'cleanUp' )
    TrialError = { 'TrialError' , P.err.( name ) } ;
  end
  
  % Default Name/Value pairs for onEntry input argument constructor. Append
  % additional pairs for this state.
  entarg = [ entarg , TrialError , { 'State' , states.( name ) , ...
    'Marker_entry' , P.evm.( [ name , '_entry' ] ) , ...
      'Marker_start' , P.evm.( [ name , '_start' ] ) , ...
        'TimeZero' , states.Start } ] ; %#ok
  
  % onEntry input arg struct
  a = onEntry_args( entarg{ : } ) ;
  
  % Default value, no SynapseAPI object is available
  a.synflg = P.UsingSynapse ;
  
  % SynapseAPI is not empty, so add pointer to this in the arg struct
  if  P.UsingSynapse , a.syn = P.syn ; end
  
  % Define state's onEntry actions
  states.( name ).onEntry = { @( ) onEntry_generic( a ) } ;
  
  % onExit marker values
  states.( name ).onExit = P.evh.( name ) ;
  
end % rows

% States with special action after having executed
for  F = fieldnames( ENDACT )' , name = F{ 1 } ;
  
  % Insert additional actions between event marker triggers
  states.( name ).onExit = [ states.( name ).onExit( 1 ) ;
                                         ENDACT.( name ) ;
                             states.( name ).onExit( 2 ) ] ;
  
end % special onExit actions

% Only HoldFix abd GetFix have different Max repetitions and ...
 states.GetFix.maxRepetitions = MAXREP_GETFIX ;
states.HoldFix.maxRepetitions = MAXREP_GETFIX + 1 ;

% ... next state following max repetisions.
 states.GetFix.nextStateAfterMaxRepetitions = MAXREP_NEXT ;
states.HoldFix.nextStateAfterMaxRepetitions = MAXREP_NEXT ;


%%% Update script's persistent and user variables %%%

persist( P )
storeUserVariables( v )


%%% CREATE TRIAL %%%

states = struct2cell( states ) ;
createTrial( 'Start' , states{ : } )

% Laser is in use
if  P.UsingSynapse
  
  % Format laser string for EchoServer
  lstr = sprintf( [ '%9sLaser %s\n%9sFreqHz %d\n%9sPhaseDeg %d\n' , ...
    '%9sEnvelope %s\n' ] , '' , c.Laser , '' , c.LaserFreqHz , '' , ...
      c.LaserPhaseDeg , '' , c.LaserEnvelope ) ;
    
  % Start of trial header
  hdr = { sprintf( 'Start trial %d;Block %d' , TrialData.currentTrial ,...
    TrialData.currentBlock ) } ;
  
  % Add condition info
  hdr = [ hdr , ...
    cellfun( @( fn ) sprintf( '%s %s' , fn , val2str( c.( fn ) ) ) , ...
      fieldnames( c )' , 'UniformOutput' , false ) ] ;
  
  % Cell of str into classic string
  hdr = strjoin( hdr , ';' ) ;

  % Send header to Synapse server
  iset( P.syn , 'RecordingNotes' , 'Note' , hdr )
  
  % Resume cyclical buffering of ephys signals
  if  P.flg.spk , P.buf.spk.startbuff( ) ; end
  if  P.flg.mua , P.buf.mua.startbuff( ) ; end
  if  P.flg.lfp && P.buf.difmualfp , P.buf.lfp.startbuff( ) ; end

% No laser
else
  
  % Default no laser string for EchoServer
  lstr = '' ;
  
end % laser

% Output to message log
EchoServer.Write( [ '\n%s Start trial %d, cond %d, block %d(%d)\n' , ...
  '%9sWait %dms = %d + %d\n%s' ] , datestr( now , 'HH:MM:SS' ) , ...
    TrialData.currentTrial , TrialData.currentCondition , ...
      TrialData.currentBlock , v.BlockType , '' , ceil( WaitMs ) , ...
        ceil( BaselineMs ) , ceil( v.WaitMs ) , lstr )


%%% Complete previous trial's inter-trial-interval %%%

sleep( ItiMinMs  -  1e3 * toc( P.ITIstart.value ) )

% Destroy any ITI stimulus and set previous to empty, in case the current
% trial has no ITI stimulus
if  ~ isempty( P.ItiStim.previous )
  delete( P.ItiStim.previous )
  P.ItiStim.previous = [ ] ;
end

% Report actual ITI in milliseconds
EchoServer.Write( '%9sITI %dms\n' , '' , ...
  ceil( 1e3 * toc( P.ITIstart.value ) ) )

% Make sure that no trial starts before buffer Gizmo timer runs down
if  P.UsingSynapse
  sleep( 1e3 * ( P.maxtimerddur - toc( P.WaitEnd.value ) ) )
end

% Error log message marking end of task script operations
logmessage( sprintf( 'Task script rt_detection.m READY trial %d, %s' , ...
  TrialData.currentTrial , cfg.sessionName ) )


%%% END OF TASK SCRIPT %%%


%%% --- SCRIPT FUNCTIONS --- %%%

% Maintain local persistent data
function  pout = persist( pin )
  
  persistent  p
  
  if  nargin  ,  p = pin ; end
  if  nargout , pout = p ; end
  
end % persist


% Task-specific checks on the validity of trial_condition_table.csv
function  tab = tabvalchk( tab , cstrreg )
  
  % Required columns, the set of column headers
  colnam = { 'ItiStimulus' , 'WaitBackground' , 'BackgroundFlickerHz' , ...
    'Target' , 'Contrast' , 'Mirror' , 'Laser' , 'LaserFreqHz' , ...
      'LaserPhaseDeg' , 'LaserMaxPowerPerChan_mW' , 'LaserEnvelope' } ;
  
  % Numerical type check
  fnumchk = @( c ) isnumeric( c ) && isreal( c ) && all( isfinite( c ) ) ;
  
  % Numeric support check
  fnumsup = @( val , sup ) val >= sup( 1 ) | val <= sup( 2 ) ;
  
  % String support check
  fstrsup = @( str , sup ) ismember( str , sup ) ;
  
  % Support error strings, for numbers and cell/string arrays
  fnumerr = @( sup ) sprintf( '[%.1f,%.1f]' , sup ) ;
  fstrerr = @( sup ) [ '{''' , strjoin( sup , ''',''' ) , '''}' ] ;
  
  % Contrast string support, allow values between 0 and 1, where contrast
  % strings are provided.
  fconsup = @( c ) fnumsup( str2double( cellfun( @( c ) [ c{ : } ] , ...
    regexp( c , cstrreg , 'tokens' , 'once' ) , ...
      'UniformOutput' , false ) ) , [ 0 , 1 ] ) ;
  
  % Error checking for each column. Return true if column's type is valid.
  valid.ItiStimulus = @iscellstr ;
  valid.WaitBackground = @iscellstr ;
  valid.BackgroundFlickerHz = fnumchk ;
  valid.Target = @iscellstr ;
  valid.Contrast = fnumchk ;
  valid.Mirror = @iscellstr ;
  valid.Laser = @iscellstr ;
  valid.LaserFreqHz = fnumchk ;
  valid.LaserPhaseDeg = fnumchk ;
  valid.LaserMaxPowerPerChan_mW = fnumchk ;
  valid.LaserEnvelope = @iscellstr ;
  
  % Support, what values are valid for each column?
  sup.ItiStimulus = { 'none' , 'mondrian' } ;
  sup.WaitBackground = { 'default' , 'red' , 'black' } ;
  sup.BackgroundFlickerHz = [ 0 , round( StimServer.GetFrameRate ) / 2 ] ;
  sup.Target = { 'none' , 'gaussian' , 'circle' , 'bar' } ;
  sup.Contrast = [ -1 , +1 ] ;
  sup.Mirror = { 'off' , 'on' } ;
  sup.Laser = { 'none' , 'test' , 'control' } ;
  sup.LaserFreqHz = [ 0 , 200 ] ;
  sup.LaserPhaseDeg = [ -Inf , +Inf ] ;
  sup.LaserMaxPowerPerChan_mW = [ 0 , 20 ] ;
  sup.LaserEnvelope = { 'none' , 'linear+' , 'uniform' } ;
  
  % Support check function
  supchk.ItiStimulus = fstrsup ;
  supchk.WaitBackground = ...
    @( str , sup ) fstrsup( str , sup ) | fconsup( str ) ;
  supchk.BackgroundFlickerHz = fnumsup ;
  supchk.Target = fstrsup ;
  supchk.Contrast = fnumsup ;
  supchk.Mirror = fstrsup ;
  supchk.Laser = fstrsup ;
  supchk.LaserFreqHz = fnumsup ;
  supchk.LaserPhaseDeg = fnumsup ;
  supchk.LaserMaxPowerPerChan_mW = fnumsup ;
  supchk.LaserEnvelope = fstrsup ;
  
  % Define support error message
  superr.ItiStimulus = fstrerr( sup.ItiStimulus ) ;
  superr.WaitBackground = fstrerr( [ sup.ItiStimulus , { cstrreg } ] ) ;
  superr.BackgroundFlickerHz = fnumerr( sup.BackgroundFlickerHz ) ;
  superr.Target = fstrerr( sup.Target ) ;
  superr.Contrast = fnumerr( sup.Contrast ) ;
  superr.Mirror = fstrerr( sup.Mirror ) ;
  superr.Laser = fstrerr( sup.Laser ) ;
  superr.LaserFreqHz = fnumerr( sup.LaserFreqHz ) ;
  superr.LaserPhaseDeg = fnumerr( sup.LaserPhaseDeg ) ;
  superr.LaserMaxPowerPerChan_mW = fnumerr( sup.LaserMaxPowerPerChan_mW ) ;
  superr.LaserEnvelope = fstrerr( sup.LaserEnvelope ) ;
  
  % Retrieve table's name
  tabnam = tab.Properties.UserData ;
  
  % Check that all required columns are present
  if  ~ all( ismember( colnam , tab.Properties.VariableNames ) )
    
    error( '%s must contain columns: %s' , ...
      tabnam , strjoin( colnam , ' , ' ) )
    
  end % all columns found
  
  % Column names, point to values
  for  C = colnam , c = C{ 1 } ; v = tab.( c ) ;
    
    % Format error string header
    errstr = sprintf( 'Column %s of %s' , c , tabnam ) ;
    
    % Check if column has correct type
    if  ~ valid.( c )( v )
      
      error( '%s has invalid type, violating %s' , ...
        errstr , func2str( valid.( c ) ) )
      
    % Support is cell array of string
    elseif  iscellstr( sup.( c ) ) %#ok
      
      % Get lower-case version of column's strings
      v = lower( v ) ;
      
      % Assign these back into the table, returned in output argument
      tab.( c ) = v ;
      
    end % error check
    
    % Values are out of range
    if  ~ all( supchk.( c )( v , sup.( c ) ) )

      error( '%s not in set %s' , errstr , superr.( c ) )

    end % range check
    
  end % cols
end % tabvalchk


% Load up laser inverse Voltage/mW-power transfer function, measured and
% saved by makelasertable. Takes session's ArcadeConfig object for paths.
% Also needs the name of .mat file from makelasertable that contains the
% inverse transfer function in piecewise polynomial struct from spline( );
% this is assumed to be one of the user added files that are backed up by
% the ARCADE session.
function  lasers = getlasercoefs( cfg , coefs )
  
  %-- Constants --%
  
  % Essential field names
  F = { 'wlen' , 'name' , 'ipos' , 'pp' , 'pmin' , 'pmax' } ;
  
  % Laser name set
  L = { 'test' , 'control' } ;
  
    % String version
    LSTR = [ '''' , strjoin( L , ''' , ''' ) , '''' ] ;
  
  
  %-- Load/check data --%

  % Name of the .mat coefficient file
  fnam = fullfile( cfg.filepaths.Backup , coefs ) ;
  
  % Check for it
  if  ~ exist( fnam , 'file' )
    error( [ 'Laser coefficient file missing. Is it in user added ' , ...
      'list?\nMissing: %s' ] , fnam )
  end
  
  % Load this into a struct
  c = load( fnam ) ;
  
  % Check for missing fields
  m = ~ isfield( c , F ) ;
  
    if  any( m )
      error( '%s missing variables: %s', fnam, strjoin( F( m ) , ' , ' ) )
    end
  
  % Number of lasers
  N = numel( c.ipos ) ;
  
  % Check for unique and valid names
  if  numel(  unique( c.name )  ) ~= N  ||  ...
        any(  ~ ismember( c.name , L )  )
    error( 'Var ''name'' in %s must be unique from set: %s' , LSTR )
  end
  
  % Lasers
  for  i = 1 : numel( c.ipos ) , nam = c.name{ i } ;
    
    % Add field to output struct with essential info. about this laser
    lasers.( nam ).index                = c.ipos( i ) ;
    lasers.( nam ).wavelength           = c.wlen( i ) ;
    lasers.( nam ).min_power_mW         = c.pmin( i ) ;
    lasers.( nam ).max_power_mW         = c.pmax( i ) ;
    lasers.( nam ).piecewise_polynomial = c.pp  ( i ) ;
    
  end % lasers
  
end % getlasercoefs


% Convert Weber contrast value c to RGB I relative to background RGB Ib.
% Reminder, Weber contrast = ( I - Ib ) / Ib where I is target luminance
% and Ib is background luminance.
function  I = Weber( c , Ib )

  % Compute 'luminance', assuming greyscale background and target
  I = Ib .* ( c + 1 ) ;
  
  % 'Hack' solution for training on black or red backgrounds. Scale zero-
  % valued RGB components from 0 to 255 by c.
  I( Ib == 0 ) = c * 255 ;
  
  % Guarantee that we don't exceed numeric range
  I = max( I ,   0 ) ;
  I = min( I , 255 ) ;
  
end % Weber


% Sample target location and size. Update editable variables. Input args
% include task script persistent variables and current value of editable
% variables.
function  [ v , RfXDeg , RfYDeg , RfRadDeg ] = newtarget( P , v )
  
  % Safeguard against infinite loop
  counter = 0 ;
  
  % Half of screen size in degrees
  hdegs = P.screendegs ./ 2 ;
  
  % Sample appropriate target location
  while  counter < 1e4
    
    % Generate cartesian coordinate in degrees from fixation point
    xy = P.screendegs .* rand( 1 , 2 )  -  hdegs ;
    
    % Round to nearest hundredth
    xy = round( xy , 2 ) ;
    
    % Eccentricity of point
    ecc = sqrt( sum( xy .^ 2 ) ) ;
    
    % RF centre radius, according to linear fit from Cavanaugh, Bair,
    % Movshon. 2002. J Neurophys. 88:2530-2546.
    rad = ( 0.0456 * ecc + 0.997 ) / 2 ;
    
    % Round to nearest hundreth
    rad = round( rad , 2 ) ;
    
    % Sampled RF centre must be a full RF radius away from fixation window
    % and also a full RF radius away from monitor edges. If not then
    % resample target location.
    if  ecc >= v.FixTolDeg + rad  &&  all( rad <= hdegs - abs( xy ) )
      break
    end
    
  end % sample targ location
  
  % Assign values
  v.RfXDeg = xy( 1 ) ;  v.RfYDeg = xy( 2 ) ;  v.RfRadDeg = rad ;
  
  % Re-assign workspace variables of same name
    RfXDeg = v.RfXDeg   ;
    RfYDeg = v.RfYDeg   ;
  RfRadDeg = v.RfRadDeg ;
  
  % Fetch ARCADE session behavioural store 
  BHVstore = SGLBehaviouralStore.launch ;
  
  % Editable variable names
  nam = BHVstore.cfg.EditableVariables( : , 1 ) ;
  
  % Editable variables to update
  for  E = { 'RfXDeg' , 'RfYDeg' , 'RfRadDeg' } , e = E{ 1 } ;
    
    % Find location in table
    i = strcmp( nam , e ) ;
    
    % Update value
    BHVstore.cfg.EditableVariables{ i , 2 } = num2str( v.( e ) ) ;
    
  end % editable variables
  
end % newtarget


% Try to send information from SynapseAPI object. Raise error on failure.
% Scalar parameters, only.
function  iset( syn , giz , par , val )
  
  % Try to set value of Gizmo parameter
  if  ~ syn.setParameterValue( giz , par , val )
    
    % Throw a simple, reader-friendly error message.
    error( [ 'Failed to set parameter %s of Gizmo %s through ' , ...
      'Synapse server on Host: %s' ] , par , giz , syn.SERVER )
    
  end % failed to set
  
end % iset


% Convert matrix to string or return string
function  str = val2str( val )
  
  % Already a string, return that. Otherwise, convert numeric matrix to
  % string.
  if  ischar( val )
    str = val ;
  else
    str = mat2str( val ) ;
  end
  
end % val2str

