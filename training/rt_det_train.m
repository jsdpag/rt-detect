
% 
% rt_det_train.m
% 
% Use Win32 Start/EndFix, Start/EndSacc events from EyeLinkServer to
% control the timing on states in this training version of the reaction
% time detection task used by Jackson Smith's optogenetics project in the
% lab of Pascal Fries.
% 


%%% CONSTANTS %%%
dbstop in rt_det_train.m at 15
% Sample wait duration
WDUR = min( exprnd( 1500 ) , expinv( 0.95 , 1500 ) ) ;

% Table of states. Each row defines a state. Column order is: state name,
% timeout duration, next state after timeout or max repetitions, wait event
% list, next state(s) after wait event(s); latter two are string or cell of
% strings.
STATE_TABLE = ...
{           'Start' , 5000 , 'Ignored'        ,     'FixIn' , 'HoldFix' ;
          'HoldFix' ,  300 , 'Wait'           ,    'FixOut' , 'LostFix' ;
             'Wait' , WDUR , 'TargetOn'       ,  { 'FixOut' , 'StartSacc' } , { 'BrokenFix' , 'FalseAlarmSaccade' } ;
         'TargetOn' ,  100 , 'ResponseWindow' ,  { 'FixOut' , 'StartSacc' } , { 'BrokenFix' , 'FalseAlarmSaccade' } ;
   'ResponseWindow' ,  400 , 'Failed'         ,  { 'FixOut' , 'StartSacc' } , { 'BrokenFix' , 'Saccade' } ;
          'Saccade' ,  125 , 'BrokenSaccade'  ,   'EndSacc' , 'GetSaccadeTarget' ;
 'GetSaccadeTarget' ,  100 , 'EyeTrackError'  ,  'StartFix' , 'Evaluate' ;
         'Evaluate' ,    0 , 'EyeTrackError'  ,  'TargetIn' , 'TargetSelected' ;
   'TargetSelected' ,    0 , 'Correct'        , 'FalseAlarmFlag' , 'FalseAlarm' ;
'FalseAlarmSaccade' ,    0 , 'Saccade'        , {} , {} ;
          'Ignored' ,    0 , 'cleanUp'        , {} , {} ;
          'LostFix' , 1000 , 'cleanUp'        , 'FixIn' , 'HoldFix' ;
        'BrokenFix' ,    0 , 'cleanUp'        , {} , {} ;
    'BrokenSaccade' ,    0 , 'cleanUp'        , {} , {} ;
    'EyeTrackError' ,    0 , 'cleanUp'        , {} , {} ; 
       'FalseAlarm' ,    0 , 'cleanUp'        , {} , {} ;
           'Missed' ,    0 , 'cleanUp'        , {} , {} ;
           'Failed' ,    0 , 'cleanUp'        , {} , {} ;
          'Correct' ,    0 , 'cleanUp'        , {} , {} ;
          'cleanUp' ,    0 , 'final'          , {} , {} ;
} ;

% Different max rep needed by these states
MAXREP.LostFix = 100 ;


%%% FIRST TRIAL INITIALISATION -- PERSISTENT DATA %%%

if  TrialData.currentTrial == 1
  
  % Open Win32 inter-process communication events
  for  E = { 'StartSacc' , 'EndSacc' , 'StartFix' , 'FalseAlarmFlag' }
    name = E{ 1 } ;
    P.( name ) = IPCEvent( name ) ;
  end
  
  % Create fixation and target stimulus handles
  P.Fix = Rectangle ;
  
    P.Fix.position = [ 0 , 0 ] ;
    P.Fix.faceColor( : ) = 255 ;
    P.Fix.width = 10 ;
    P.Fix.height = 10 ;
    P.Fix.angle = 45 ;
  
  P.Target = Gaussian ;
  
    P.Target.position = [ +420 , -262 ] ;
    P.Target.sdx = 80 ;
    P.Target.sdy = 80 ;
    P.Target.color( : ) = 255 ;
  
  % Keep persistent store of IPCEvent handles
  persist( P )
  
  % Create fixation and target eye windows
  trackeye( P.Fix.position    ,  50 , 'Fix'    )
  trackeye( P.Target.position , 200 , 'Target' )
  
% Retrieve persistent data
else
  
  P = persist ;
  
end % first trial init


%%% MAKE ARCADE STATES %%%

% State table rows
for  row = 1 : size( STATE_TABLE , 1 )
  
  % Map table entry to meaningful names
  [ name, timeout, tout_next, waitev, wait_next ] = STATE_TABLE{ row , : };
  
  % Create new state
  states.( name ) = State( name ) ;
  
  % Set timeout duration, max number executions, and next state after
  % timeout or max reps. Max reps = 2 so that no inf loops, and don't trig
  % wrong state.
  states.( name ).duration                     =   timeout ;
  states.( name ).maxRepetitions               =         2 ;
  states.( name ).nextStateAfterTimeout        = tout_next ;
  states.( name ).nextStateAfterMaxRepetitions = tout_next ;
  states.( name ).waitEvents                   =    waitev ;
  states.( name ).nextStateAfterEvent          = wait_next ;
  
  % Want different number of maximum executions for state
  if  isfield( MAXREP , name )
    states.( name ).maxRepetitions = MAXREP.( name ) ;
  end
  
end % rows


%%% DEFINE STATE ACTIONS %%%

% HoldFix turns Fix point on
states.HoldFix.onEntry = { @() set( P.Fix.visible , 1 ) } ;

% LostFix turns Fix point off
states.HoldFix.onEntry = { @() set( P.Fix.visible , 0 ) } ;

% Wait resets saccade and FA events
E = { P.StartSacc , P.EndSacc , P.FalseAlarmFlag } ;
states.Wait.onEntry = { @() cellfun( @( e ) e.reset , E ) } ;

% TargetOn makes target visible
states.TargetOn.onEntry = { @() set( P.Target , 'visible' , 1 ) } ;

% FalseAlarmSaccade raises FalseAlarmFlag event
states.FalseAlarmSaccade.onEntry = { @() P.FalseAlarmFlag.trigger } ;

% Saccade resets StartFix event
states.Saccade.onEntry = { @() P.StartFix.reset } ;

% cleanUp makes all visual stimuli disappear
E = { P.Fix , P.Target } ;
states.cleanUp.onEntry = ...
  { @() cellfun( @( s ) set( s , 'visible' , 0 ) , E ) } ;


%%% CREATE TRIAL %%%

states = struct2cell( states ) ;
createTrial( 'Start' , states{ : } )


%%% --- SCRIPT FUNCTIONS --- %%%

% Maintain local persistent data
function  pout = persist( pin )
  
  persistent  p
  
  if  nargin  ,  p = pin ; end
  if  nargout , pout = p ; end
  
end % persist

