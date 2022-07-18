
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
  
  % Create name for each block
  blk.nam = arrayfun( @( t ) sprintf( 'Block %d' , t ) , blk.typ , ...
    'UniformOutput' , false ) ;
  
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
  fh.Position( 3 ) = ( 1 + 1/3 ) * ofig.fig.Position( 3 ) ; % width
  fh.Position( 4 ) =         0.9 * ofig.fig.Position( 4 ) ; % height
  
  % ... position the figure
  fh.Position( 1 : 2 ) = [ 1 , 31 ] ;
  
  
  %%% Create axes %%%
  
  % Outcome raster plot
  ofig.subplot( 6 , 3 , [  1 ,  2 ] , 'Tag' , 'Raster'        ) ;
  
  % Current/previous trial info
  ofig.subplot( 6 , 3 , [  3 ,  9 ] , 'Tag' , 'Info'          ) ;
  
  % Psychometric curves
  ofig.subplot( 6 , 3 , [  4 , 16 ] , 'Tag' , 'Psychometric'  ) ;
  
  % Reaction time curves
  ofig.subplot( 6 , 3 , [  5 , 17 ] , 'Tag' , 'Reaction Time' ) ;
  
  % Grand reaction time histogram
  ofig.subplot( 6 , 3 , [ 12 , 18 ] , 'Tag' , 'RT Histogram'  ) ;
  
  
  %%% Colour name to RGB map %%%
  
  % Axes all have the same default ColorOrder set, point to one of them
  col = fh.Children( 1 ).ColorOrder ;
  
  % Define a struct mapping field names to corresponding RGB values
  col = struct( 'green' , col( 5 , : ) , ...
                 'blue' , col( 1 , : ) , ...
               'yellow' , col( 3 , : ) , ...
                 'plum' , col( 4 , : ) ) ;
  
  
  %%% Populate each axis with appropriate graphics objects %%%
  
  %-- Behav raster --%
  
  % Find its handle
  ax = findobj( fh , 'Tag' , 'Raster' ) ;
  
  % Create group data struct
  
    % Number of trials to track in raster
    dat.N = 500 ;
    
    % Session name for axes Title format string
    dat.nam = cfg.sessionName ;
  
    % Remember trial outcome (error) codes for key outcomes
    dat.out.Corr  = err.Correct    ;
    dat.out.Fail  = err.Failed     ;
    dat.out.False = err.FalseAlarm ;
    
    % Trial counters
    dat.cnt.Corr   = 0 ;
    dat.cnt.Fail   = 0 ;
    dat.cnt.False  = 0 ;
    dat.cnt.Trials = 0 ; % Only correct, failed, and false alarm
  
  % Axis limits
  axis( ax , [ 0.5 , dat.N + 0.5 , -0.25 , 3.25 ] )
  
  % Don't show the axes object, itself
  axis( ax , 'off' )
  
  % Initialise axes title, show string as is without any Tex interpretation
  set( ax.Title , 'String' , dat.nam , 'Interpreter' , 'none' , ...
    'HorizontalAlignment' , 'left' , 'FontSize' , 10 )
  
  % Switch units to pixels ...
  set( [ ax , ax.Title ] , 'Units' , 'pixels' )
  
  % ... so that we can position title near left edge of figure
  ax.Title.Position( 1 ) = -0.8 * ax.Position( 1 ) ;
  ax.Title.Position( 2 ) = 2 + ax.Title.Position( 2 ) ;
  
  % Raster labels
  y = 4 ;
  for  F = { 'corr' , 'fail' , 'false' , 'other' } , f = F{ 1 }; y = y - 1;
    
    text( ax , -0.01 * dat.N , y , f , 'HorizontalAlignment' , 'right' ,...
       'FontName' , 'Arial' , 'FontSize' , 9 )
    
  end % raster labels
  
  % X-axis and baseline y-axis values
  x =   nan( 1 , dat.N ) ;
  y = zeros( 1 , dat.N ) ;
  
  % Create rasters
  h = [ ...
plot( ax, x, y + 3, '.', 'MarkerEdgeColor', col.green , 'Tag' , 'Corr'  ) ;
plot( ax, x, y + 2, '.', 'MarkerEdgeColor', col.blue  , 'Tag' , 'Fail'  ) ;
plot( ax, x, y + 1, '.', 'MarkerEdgeColor', col.yellow, 'Tag' , 'False' ) ;
plot( ax, x, y + 0, '.', 'MarkerEdgeColor', col.plum  , 'Tag' , 'Other' )];
  
  % Add graphics object group to onlinefigure
  ofig.addgroup( 'BehavRaster', '', dat, [ ax , h'], @fupdate_behavraster )
  
  
  %-- Trial information --%
  
  % Find axes
  ax = findobj( fh , 'Tag' , 'Info' ) ;
  
  % Lock axes limits
  axis( ax , [ 0 , 1 , 0 , 1 ] )
  
  % Hide axes
  axis( ax , 'off' )
  
  % Alter err into a struct with cell array of error names in .nam and
  % error codes in .val. Fields are in register so that finding error in
  % .val by code yields the index required to find the error name in .nam.
  dat = struct( 'nam', { fieldnames( err ) }, 'val', struct2array( err ) );
  
  % Add text object to report trial info
  h = text( ax , 0 , 0.5 , '' , 'FontName' , 'Arial' ) ;
  
  % Add group
  ofig.addgroup( 'TrialInfo' , '' , dat , h , @fupdate_trialinfo )
  
  
  %-- Reaction time histogram --%
  
  % Find axes
  ax = findobj( fh , 'Tag' , 'RT Histogram' ) ;
  
  % Lock x-axis limits, in milliseconds
  xlim( ax , [ 0 , 500 ] )
  
  % Labels
  xlabel( ax , 'Reaction time (ms)' )
  ylabel( ax , 'Trials' )
  
  % Centre of RT bins
  x = 5 : 10 : 495 ;
  
  % Initialise bar height
  y = zeros( size( x ) ) ;
  
  % Selection display parameters for bar and text objects
  selpar = { { 'EdgeColor', 'k', 'FaceColor', col.blue, 'BarWidth', 1 } ;
             { 'Visible', 'on' } } ;
  unspar = { { 'EdgeColor', 'none', 'FaceColor', [ 0.6 , 0.6 , 0.6 ], ...
    'BarWidth', 0.9 } ; { 'Visible', 'off' } } ;
  
  % Collect information about bin number and width. Also, get trial error
  % code for correct trial outcome. Also, maintain a total RT sum and trial
  % count.
  dat = struct( 'N', numel( x ), 'width', 10, 'Correct', err.Correct, ...
    'RTsum', 0, 'trials', 0 ) ;
  
  % Blocks of trials. Get group and set identifiers (id & nam).
  for  i = 1 : blk.N , nam = blk.nam{ i } ; id = [ nam , ' RT' ] ;
    
    % Create bar object to draw the histogram and text object to report the
    % mean RT
    h = [  bar( ax , x , y , 1 , selpar{ 1 }{ : } , 'Tag' , 'data' ) , ...
          text( ax, 1, 1, '', 'Units', 'normalized', 'Tag', 'avg', ...
            'HorizontalAlignment', 'right', 'VerticalAlignment', 'top' ) ];
    
    % Create new graphics objects group.
    ofig.addgroup( id , nam , dat , h , @fupdate_rthist )
    
    % Bind selection and un-selection parameters
    ofig.bindparam( id , 'seldata'   , selpar{ : } )
    ofig.bindparam( id , 'unseldata' , unspar{ : } )
    
  end % blocks of trials
  
  
  %%% Done %%%
  
  fh.Visible = 'on' ;
  
end % creatbehavfig


%%% Define data = fupdate( hdata , data , index , newdata ) %%%

% Tally trials and report in axes title. Adjust raster tick position and
% highlight trial outcome. Maintain dividers to show different blocks.
% index is not required. newdata must be a struct with fields
%   .pre_err - Trial error code of the previous trial.
%   .pre_block - Block index (not type, index) of previous trial.
%   .nex_block - Block index of the next, upcoming trial.
function  data = fupdate_behavraster( hdata , data , ~ , newdata )
  
  % Determine the outcome of the previous trial, and whether to increment
  % the trial count.
  switch  newdata.pre_err
    case  data.out.Corr  , err = 'Corr'  ;
    case  data.out.Fail  , err = 'Fail'  ;
    case  data.out.False , err = 'False' ;
    otherwise            , err = 'Other' ;
  end
  
  % Update trial tally if error string not 'Other'
  if  err( 1 ) ~= 'O'
    data.cnt.Trials  = 1  +  data.cnt.Trials  ;
    data.cnt.( err ) = 1  +  data.cnt.( err ) ;
  end
  
  % Cell array of title sub-strings
  C = cell( 1 , 5 ) ;
  
  % Session name first
  C{ 1 } = data.nam ;
  
  % Trial outcomes, retrieve name, and increment string index
  i = 1 ;
  for  F = { 'Corr', 'Fail', 'False' } , f = F{ 1 } ; i = i + 1 ;
    
    % Count and percentage
    cnt = data.cnt.( f ) ;
    per = data.cnt.( f ) / data.cnt.Trials * 100 ;
    
    % Format <outcome> <count>(<% trials>)
    C{ i } = sprintf( '%s %d(%.1f%%)' , f , cnt , per ) ;
    
  end % outcomes
  
  % Last, the total number of tallied trials
  C{ end } = sprintf( 'Trials %d' , data.cnt.Trials ) ;
  
  % Get axes
  ax = findobj( hdata , 'Type' , 'axes' , 'Tag' , 'Raster' ) ;
  
  % Format new title string for axes
  ax.Title.String = strjoin( C , ', ' ) ;
  
  % Raster lines, we know that these are not the axes
  for  h = hdata( hdata ~= ax )
    
    % Shift all data points to the left
    h.XData( : ) = [ h.XData( 2 : end ) - 1 , NaN ] ;
    
    % Previous trial error is represented by this raster line, show trial
    if  strcmp( h.Tag , err ) , h.XData( end ) = data.N ; end
    
  end % raster lines
  
  % Block divider lines
  for  h = findobj( ax , 'Tag' , 'block' )'
    
    % Subtract position by one trial
    h.XData( : ) = h.XData - 1 ;
    
    % Line falls off edge of axes, kill it
    if  h.XData( 1 ) < ax.XLim( 1 ) , delete( h ) , end
    
  end % block lines
  
  % New block line is needed
  if  newdata.pre_block ~= newdata.nex_block
    
    plot( ax , ax.XLim( [ 2 , 2 ] ) , ax.YLim , 'Tag' , 'block' , ...
      'Color' , [ 0.6 , 0.6 , 0.6 ] )

  end % new block
  
end % fupdate_behavraster


% Simply re-format info string with prev- and next trial info. All of
% this is provided in struct newdata. Each field is a 1x2 vector containing
% [ prev , next ] trial data. Fields:
%   .ind - Trial indices
%   .err - Trial error codes
%   .con - Trial conditions
%   .blk - Block indices
%   .typ - Block types
%   .rt  - Reaction times
%
% There is one additional set of fields. These are scalar values:
%   .trials - Number of correct/failed trials collected in the current
%      block.
%   .total - Total number of trials required by block.
function  data = fupdate_trialinfo( hdata , data , ~ , newdata )
  
  % Accumulate info string
  str = cell( 1 , 3 ) ;
  
  % Init prev/next index
  i = 0 ;
  
  % Previous and next trials
  for  F = { 'Prev' , 'Next' } , f = F{ 1 } ; i = i + 1 ;
    
    % Empty cell of strings
    C = cell( 1 , 5 ) ;
    
    % Trial index
    C{ 1 } = sprintf( '%s trial: %d\n' , f , newdata.ind( i ) ) ;
    
    % Block index and type
    C{ 2 } = sprintf( '  Block(type): %d(%d)\n' , ...
      newdata.blk( i ) , newdata.typ( i ) ) ;
    
    % And trial condition
    C{ 3 } = sprintf( '  Cond: %d' , newdata.con( i ) ) ;
    
    % Previous trial has more info
    if  strcmp( f , 'Prev' )
      
      % Search for trial error code in list
      e = data.val == newdata.err( i ) ;
      
      % Trial outcome name
      C{ 4 } = sprintf( '\n  Result: %s\n' , data.nam{ e } ) ;
      
      % Reaction time
      C{ 5 } = sprintf( '  RT: %dms' , ceil( newdata.rt( i ) ) ) ;
      
    end % prev trial
    
    % Concatenate and accumulate
    str{ i } = [ C{ : } , ...
      sprintf( '\\fontsize{2}\n\\fontsize{%d}\n' , hdata.FontSize ) ] ;
    
  end % prev / next trial
  
  % Block's trial count
  str{ end } = sprintf( 'Trials/Total: %d/%d (%.1f%%)', ...
    newdata.trials, newdata.total, newdata.trials / newdata.total * 100 ) ;
  
  % Show string after final concatenation
  hdata.String = [ str{ : } ] ;
  
end % fupdate_trialinfo


% Block-wide reaction time histogram. newdata is the trial error code of
% previous trial. index is the reaction time of previous trial.
function  data = fupdate_rthist( hdata , data , index , newdata )
  
  % Check if previous trial was correct. If not, return immediately because
  % there is no valid reaction time.
  if  data.Correct ~= newdata , return , end
  
  % Find the bar
  hbar = findobj( hdata , 'Tag' , 'data' ) ;
  
  % Compute index of bin that tallies new reaction time
  i = min( ceil( index / data.width ) , data.N ) ;
  
  % Count one more trial
  hbar.YData( i ) = hbar.YData( i ) + 1 ;
  
  % Accumulate sum
  data.RTsum  = data.RTsum  + index ;
  data.trials = data.trials + 1     ;
  
  % Find average RT text object
  htext = findobj( hdata , 'Tag' , 'avg' ) ;
  
  % Format string with latest average RT
  htext.String = sprintf( '%dms\navg', round( data.RTsum / data.trials ) );
  
end % fupdate_rthist

