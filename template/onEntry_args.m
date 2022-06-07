
function  ain = onEntry_args( varargin )
%
% ain = onEntry_args( <Name string> , <value> , ... )
% 
% Build input argument struct for state action function. Provide Name/Value
% pairs. Names are also the fields of ain output struct.
% 
% Valid names are:
% 
%      'State' - Handle to calling state.
%'Marker_entry'- Integer event marker value sent out of DAQ digital ports
%                before other onEntry functions execute. Must be natural
%                number between 0 and 2 ^ 16 - 1 i.e. intmax( 'uint16' ).
%'Marker_start'- Same as Marker_entry, but this event marker is issued
%                after all other onEntry functions.
%       'Stim' - ARCADE stimulus handle(s), visibility is simply flipped to
%                opposite state. Give as cell array of handle(s).
%      'Reset' - Array of IPCEvent handles, all connected Win32 events are
%                reset.
%    'Trigger' - Same as 'Reset', but Win32 events are triggered rather
%                than re-set.
% 'TrialError' - Scalar numeric trial error code.
% 'Photodiode' - Char vector i.e. string of valid input for photodiode
%                helper function.
%   'TimeZero' - Handle to State object, its startTic value is used as time
%                zero, against which time is measured.
% 'RunTimeVal' - Handle to StateRuntimeVariable in which elapsed seconds
%                since time zero is stored.
%     'Reward' - Scalar integer, reward size in milliseconds.
% 
% Additional field ain.flg is a struct with fields listed above, but each
% contains a scalar logical indicating whether or not the Name/Value pair
% was provided. flg.grpstim is true if there are multiple stimuli, or a
% photodiode command and one or more simuli, thus requiring a grouping
% operation.
% 
% Jackson Smith - May 2022 - Fries Lab (ESI Frankfurt)
% 
  
  % Default ain field name set
  ain = { 'State', 'Marker', 'Stim', 'Reset', 'Trigger', 'TrialError', ...
    'Photodiode', 'TimeZero', 'RunTimeVal' , 'Reward' } ;
  
  % Valid input for photodiode( )
  phostr = { 'on' , 'off' , 'toggle' , 'flicker' } ;
  
  % Error checking values, returns logical true if input IS valid
  ech.State = @( v ) isscalar( v ) && isa( v , 'State' ) ;
  ech.Marker_entry = @( v ) isscalar( v ) && isnatnum( v, 0, 2 ^ 16 - 1 ) ;
  ech.Marker_start = ech.Marker_entry ;
  ech.Stim = @( v ) iscell( v ) && ...
    all( cellfun( @( v ) isa( v , 'Stimulus' ) , v ) ) ;
  ech.Reset = @( v ) isa( v , 'IPCEvent' ) ;
  ech.Trigger = ech.Reset ;
  ech.TrialError = @( v ) isscalar( v ) && isnatnum( v , 1 , 9 ) ;
  ech.Photodiode = @( v ) isrow( v ) && ischar( v ) && ...
    any( strcmp( v , phostr ) ) ;
  ech.TimeZero = ech.State ;
  ech.RunTimeVal = @( v ) isscalar( v ) && ...
    isa( v , 'StateRuntimeVariable' ) ;
  ech.Reward = @( v ) isscalar( v ) && isnatnum( v ) ;
  
  % Error messages
  ems.State = 'ARCADE State' ;
  ems.Marker_entry = 'valid event marker' ;
  ems.Marker_start = ems.Marker_entry ;
  ems.Stim = 'cell array of ARCADE Stimulus objects' ;
  ems.Reset = 'IPCEvent array' ;
  ems.Trigger = ems.Reset ;
  ems.TrialError = 'valid trial error number' ;
  ems.Photodiode = sprintf( 'one of: ''%s''' , ...
    strjoin( phostr , ''' , ''' ) ) ;
  ems.TimeZero = ems.State ;
  ems.RunTimeVal = 'StateRuntimeVariable' ;
  ems.Reward = 'natural number' ;
  
  % Append second row of empty double arrays
  ain = [ ain ; cell( size( ain ) ) ] ;
  
  % Make a copy for logical flags
  flg = ain ;
  
    % Replace empty arrays with scalar logical false
    flg( 2 , : ) = { false } ;
  
  % Create struct of valid input names, for mapping to input values
  ain = struct( ain{ : } ) ;
  flg = struct( flg{ : } ) ;
  
  % Scan input Name/Value pairs
  for  i = 1 : 2 : nargin , nam = varargin{ i } ; val = varargin{ i + 1 } ;
    
    % Error check value
    if  ~ ech.( nam )( val )
      error( '%s must be %s' , nam , ems.( nam ) )
    end
    
    % Store value
    ain.( nam ) = val ;
    
    % Raise flag
    flg.( nam ) = true ;
    
  end % name/val
  
  % Create an additional flag. Raise this if it is necessary to group
  % stimuli before drawing the next frame. This is the case when there are
  % more than one stimulus and/or at least one stimulus with a photodiode
  % change.
  flg.grpstim = numel( ain.Stim ) > 1  ||  ( flg.Stim && flg.Photodiode ) ;
  
  % Store flags in return struct
  ain.flg = flg ;
  
end % argstruct


%%% Sub-routines %%%

% Check if n is a natural number
function  valid = isnatnum( n , nmin , nmax )
  
  if  nargin < 3 , nmax = Inf ; end
  if  nargin < 2 , nmin =   0 ; end
  
  valid = isnumeric( n ) && isreal( n ) && all( isfinite( n ) ) && ...
    all( nmin <= n ) && all( nmax >= n ) ;
  
end % isnatnum

