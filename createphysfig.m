
function  ofig = createphysfig( cfg , evar , tab )
% 
% ofig = createphysfig( cfg , evar , tab )
% 
% Create and initialise electrophysiology plots. Called by task script. cfg
% is the ArcadeConfig object of the current session. evar is a struct
% containing all editable variables. tab is a Table object containing
% processed version of trial_condition_table.csv, which defines all trial
% conditions and groups them into blocks of trials. Returns an onlinefigure
% object. Create plots before running the first trial.
% 
% Note, creates secondary figure window that allows selection of channel in
% the main window.
% 
  
  
  %%% CONSTANTS %%%
  
  % arrayfun & cellfun that always returns results in a cell array
  arfc = @( varargin ) arrayfun( varargin{ : } , 'UniformOutput' , false );
  crfc = @( varargin )  cellfun( varargin{ : } , 'UniformOutput' , false );
  
  % Sampling rate for plotted data.
  C.fs = 1e3 ;
  
  % X-axis time bins for time plots. Also used to interpolate continuous
  % data down to 1kHz. In milliseconds.
  C.time = - evar.BaselineMs : evar.ReacTimeMinMs + evar.RespWinWidMs ;
  
  % Size of time window for Fourier transform, in milliseconds
  C.N.win = 200 ;
  
  % fft interpolation, producing this many frequency bins
  C.N.fft = 1e3 ;
  
  % Hann window, apply to windowed time data for FFT
  C.hann = hann( C.N.win ) ;
  
  % Frequency bins, in Hz
  C.freq = ( 0 : C.N.fft - 1 ) * ( C.fs / C.N.fft ) ;
  
  % Maximum kept frequency bin, in Hz
  C.maxfreq = 100 ;
  
  % Logical index vector for kept frequency bins
  C.ifreq = C.freq <= C.maxfreq ;
  
  % Time and frequency windows, Hann window, other defaults.
  
  
  
  %%% Blocks of trials %%%
  
  % Unique BlockType values. Here 'Block Type' means a unique grouping of
  % trial conditions.
  blk.typ = unique( tab.BlockType ) ;
  
  % Number of block types
  blk.N = numel( blk.typ ) ;
  
  % Create name for each block
  blk.nam = arfc( @( t ) sprintf( 'Block %d' , t ) , blk.typ ) ;
  
  
  %%% Create main figure %%%
  
  % Determine the save name of the onlinefigure
  fnam = [ fullfile( cfg.filepaths.Behaviour , ...
             [ cfg.sessionName , '_ephys' ] ) , '.fig' ] ;
  
  % Create onlinefigure object, it starts out being invisible
  ofig = onlinefigure( fnam , 'Tag' , 'Ephys' , 'Visible' , 'off' ) ;
  
  % Point to ephys figure handle
  fh = ofig.fig ;
  
  % Point to root graphics and behaviour figure handle
  gh = groot ;
  bh = findobj( 'Type' , 'figure' , 'Tag' , 'Behaviour' ) ;
  
  % Shape and ...
  fh.Position( 3 ) = gh.ScreenSize( 3 ) - bh.Position( 3 ) ; % width
  fh.Position( 4 ) = bh.Position( 4 ) ; % height
  
  % ... position the figure
  fh.Position( 1 : 2 ) = [ bh.Position( 3 ) + 1 , 31 ] ;
  
  
  %%% Create channel selection list box %%%
  
  % First, find the ARCADE remote, which is used by this task
  rh = findobj( 'Type' , 'figure' , 'Tag' , 'remote' ) ;
  
  % Make channel selection figure
  ch = figure( 'MenuBar' , 'none' , 'ToolBar' , 'none' , 'Tag' , ...
    'Channel' , 'Visible' , 'off' ) ;
  
  % Shape and ...
  ch.OuterPosition( 3 ) = rh.OuterPosition( 3 ) ;
  ch.OuterPosition( 4 ) = rh.Position( 2 ) - fh.OuterPosition( 2 ) - ...
    fh.OuterPosition( 4 ) ;
  
  % ... position the figure
  ch.Position( 1 ) = rh.Position( 1 ) ;
  ch.Position( 2 ) = fh.OuterPosition( 2 ) + fh.OuterPosition( 4 ) ;
  
  % Selection list box
  lstbox = uicontrol( ch , 'Style' , 'listbox' , 'String' , ...
    arrayfun( @( i ) sprintf( 'Tdt Chan %d' , i ), 1 : evar.TdtChannels,...
      'UniformOutput' , false ), 'Tag', 'chansel' ) ;
  
  % Position box
  lstbox.Units = 'normalized' ;
  lstbox.Position( 1 : 2 ) = 0.025 ;
  lstbox.Position( 3 : 4 ) = 0.950 ;
  
  
  %%% Create axes %%%
  
  % Spike rate time and frequency plots
  ofig.subplot( 3 , 2 , 1 , 'Tag' , 'SpikeTime' ) ;
  ofig.subplot( 3 , 2 , 2 , 'Tag' , 'SpikeFreq' ) ;
  
  % Multi unit activity time and frequency plots
  ofig.subplot( 3 , 2 , 3 , 'Tag' , 'MuaTime' ) ;
  ofig.subplot( 3 , 2 , 4 , 'Tag' , 'MuaFreq' ) ;
  
  % Local field potential time and frequency plots
  ofig.subplot( 3 , 2 , 5 , 'Tag' , 'LfpTime' ) ;
  ofig.subplot( 3 , 2 , 6 , 'Tag' , 'LfpFreq' ) ;
  
  
  %%% Colour name to RGB map %%%
  
  % Axes all have the same default ColorOrder set, point to one of them
  col = fh.Children( 1 ).ColorOrder ;
  
  % Define a struct mapping field names to corresponding RGB values
  col = struct( 'green' , col( 5 , : ) , ...
                 'blue' , col( 1 , : ) , ...
               'yellow' , col( 3 , : ) , ...
                 'plum' , col( 4 , : ) , ...
                'lgrey' , [ 0.6 , 0.6 , 0.6 ] ) ;
  
  % Map colours to target and laser types from table 'Target' and 'Laser'
  col.Target.none     = col.blue   ;
  col.Target.gaussian = col.green  ;
   col.Laser.none     = col.blue   ;
   col.Laser.test     = col.green  ;
   col.Laser.control  = col.yellow ;
  
  
  %%% Done %%%
  
  % Apply formatting through selection of first block, by default
%   ofig.select( 'set' , blk.nam{ 1 } )
ofig.fnam = '' ; % remove after testing
  
  % Show thine creations
  fh.Visible = 'on' ;
  ch.Visible = 'on' ;
  
  
end % createphysfig

