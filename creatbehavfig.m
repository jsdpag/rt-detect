
function  ofig = creatbehavfig( cfg , err , tab )
% 
% ofig = creatbehavfig( cfg , err , tab )
% 
% Create and initialise behaviour plots. Called by task script. cfg is the
% ArcadeConfig object of the current session. err is the struct output from
% gettrialerrors mapping the name of each trial outcome to its numeric
% code. tab is a Table object containing processed version of
% trial_condition_table.csv, which defines all trial conditions and groups
% them into blocks of trials. Returns an onlinefigure object. Create plots
% before running the first trial.
% 
  
  
  %%% Blocks of trials %%%
  
  % Unique BlockType values. Here 'Block Type' means a unique grouping of
  % trial conditions.
  blk.typ = unique( tab.BlockType ) ;
  
  % Number of block types
  blk.N = numel( blk.typ ) ;
  
  % Find corresponding sets of target contrasts. This will be the
  % independent variable in the psychometric and RT plots. Return as cell
  % array of vectors.
  blk.x = arrayfun( @( t ) unique( tab.Contrast( tab.BlockType == t ) ),...
    blk.typ , 'UniformOutput' , false ) ;
  
  % Global minimum and maximum contrast value
  blk.min = min( [ blk.x{ : } ] ) ;
  blk.max = max( [ blk.x{ : } ] ) ;
  
  % Range
  blk.rng = blk.max - blk.min ;
  
  % X-axis limits +/- 2.5%
  blk.lim = [ -0.025 , +0.025 ] * blk.rng  +  [ blk.min , blk.max ] ;
  
  
  %%% Create figure %%%
  
  % Determine the save name of the onlinefigure
  fnam = [ fullfile( cfg.filepaths.Behaviour, cfg.sessionName ) , '.fig' ];
  
  % Create onlinefigure object, it starts out being invisible
  ofig = onlinefigure( fnam , 'Tag' , 'Behaviour' , 'Visible' , 'off' ) ;
  
  % Point to figure handle
  fh = ofig.fig ;
  
  % Shape and ...
  fh.Position( 3 ) = ( 1 + 2/3 ) * ofig.fig.Position( 3 ) ; % width
  fh.Position( 4 ) =         0.9 * ofig.fig.Position( 4 ) ; % height
  
  % ... position the figure
  fh.Position( 1 : 2 ) = [ 1 , 31 ] ;
  
  
  %%% Create axes %%%
  
  % Outcome raster plot
  ofig.subplot( 6 , 3 , [  1 ,  2 ] , 'Tag' , 'Raster'        ) 
  
  % Current/previous trial info
  ofig.subplot( 6 , 3 , [  3 ,  9 ] , 'Tag' , 'Info'          )
  
  % Psychometric curves
  ofig.subplot( 6 , 3 , [  4 , 16 ] , 'Tag' , 'Psychometric'  )
  
  % Reaction time curves
  ofig.subplot( 6 , 3 , [  5 , 17 ] , 'Tag' , 'Reaction Time' )
  
  % Grand reaction time histogram
  ofig.subplot( 6 , 3 , [ 10 , 18 ] , 'Tag' , 'RT Histogram' )
  
  
  %%% Colour name to RGB map %%%
  
  % Axes all have the same default ColorOrder set, point to one of them
  colour = fh.Children( 1 ).ColorOrder ;
  
  % Define a struct mapping field names to corresponding RGB values
  colour = struct( 'green' , colour( 5 , : ) , ...
                    'blue' , colour( 1 , : ) , ...
                  'yellow' , colour( 3 , : ) , ...
                   'black' , [ 0 , 0 , 0 ] ) ;
  
  
  %%% Populate each axis with appropriate graphics objects %%%
  
  %-- Behav raster --%
  
  % Find its handle
  ax = findobj( fh , 'Tag' , 'Raster' ) ;
  
  % Set as current axes
  axes( ax )
  
  % Create group data struct
  
    % Number of trials to track in raster
    dat.N = 500 ;
    
    % Session name for axes Title format string
    dat.nam = cfg.sessionName ;
  
    % Remember trial outcome (error) codes for key outcomes
    dat.out.Correct    = err.Correct    ;
    dat.out.Failed     = err.Failed     ;
    dat.out.FalseAlarm = err.FalseAlarm ;
    
    % Trial counters
    dat.cnt.Correct    = 0 ;
    dat.cnt.Failed     = 0 ;
    dat.cnt.FalseAlarm = 0 ;
    dat.cnt.Trials     = 0 ; % Only correct, failed, and false alarm
  
  % Axis limits
  axes( [ 0.5 , dat.N + 0.5 , 0 , 3 ] )
  
  % Don't show the axes object, itself
  axis  off
  
  % Initialise axes title
  title( dat.nam )
  
  % X-axis and baseline y-axis values
  x =   nan( 1 , dat.N ) ;
  y = zeros( 1 , dat.N ) ;
  
  % Create rasters
  h = [ ...
plot( x, y + 3, '.', 'MarkerEdgeColor', col.green , 'Tag' , 'Correct'    );
plot( x, y + 2, '.', 'MarkerEdgeColor', col.blue  , 'Tag' , 'Failed'     );
plot( x, y + 1, '.', 'MarkerEdgeColor', col.yellow, 'Tag' , 'FalseAlarm' );
plot( x, y + 0, '.', 'MarkerEdgeColor', col.green , 'Tag' , 'Other' ) ]' ;
  
  % Add graphics object group to onlinefigure
  ofig.addgroup( 'BehavRaster', '', dat, [ ax , h ], @fupdate_behavraster )
  
  
end % creatbehavfig


%%% Define data = fupdate( hdata , data , index , newdata ) %%%

function  fupdate_behavraster( hdata , data , index , newdata )
end % fupdate_behavraster

