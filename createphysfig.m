
function  [ ofig , chlst ] = createphysfig( cfg , evar , tab , buf )
% 
% [ ofig , chlst ] = createphysfig( cfg , evar , tab , buf )
% 
% Create and initialise electrophysiology plots. Called by task script. cfg
% is the ArcadeConfig object of the current session. evar is a struct
% containing all editable variables. tab is a Table object containing
% processed version of trial_condition_table.csv, which defines all trial
% conditions and groups them into blocks of trials. Returns an onlinefigure
% object. Create plots before running the first trial. Also returns list
% box for selecting ephys channel to display; this is used by task script
% to refresh the display.
% 
% buf has fields spk , mua , lfp storing handles to spike, multiunit
% activity, and local field potential buffer object handles.
% 
% Note, creates secondary figure window that allows selection of channel in
% the main window.
% 
  
  
  %%% CONSTANTS %%%
  
  % arrayfun & cellfun that always returns results in a cell array
  arfc = @( varargin ) arrayfun( varargin{ : } , 'UniformOutput' , false );
  crfc = @( varargin )  cellfun( varargin{ : } , 'UniformOutput' , false );
  
  % Axis labels
  L.X.time = 'Time from target on (ms)' ;
  L.X.freq = 'Frequency (Hz)' ;
  L.Y.time = '' ;
  L.Y.freq = 'dB ' ;
  
  % Pointers to buffer objects
  C.buf.spk = buf.spk ;
  C.buf.mua = buf.mua ;
  C.buf.lfp = buf.lfp ;
  
  % Remove empty fields
  for  M = fieldnames( C.buf )' ; m = M{ 1 } ;
    if  isempty( C.buf.( m ) ) , C.buf = rmfield( C.buf , m ) ; end
  end
  
  % Data modalities, name strings
  C.modality = fieldnames( C.buf )' ;
  
  % Number of data modalities
  C.N.modality = numel( C.modality ) ;
  
    % No TdtWinBuf objects provided, so ephys plots are not possible
    if  C.N.modality == 0 , ofig = [ ] ; chlst = [ ] ; return , end
  
  % Data domains
  C.domain = { 'time' , 'freq' } ;
  
  % Number of data domains
  C.N.domain = numel( C.domain ) ;
  
  % Number of TDT channels
  C.N.chan = evar.TdtChannels ;
  
  % Remember modality specific channel indices for data buffers
  C.ichan.spk = 1 : C.N.chan ;
  C.ichan.mua = evar.MuaStartIndex : evar.MuaStartIndex + C.N.chan - 1 ;
  C.ichan.lfp = evar.LfpStartIndex : evar.LfpStartIndex + C.N.chan - 1 ;
  
  % Sampling rate for plotted data.
  C.fs = 1e3 ;
  
  % X-axis time bins for time plots. Also used to interpolate continuous
  % data down to 1kHz. In milliseconds.
  C.time = - evar.BufBaselineMs : evar.ReacTimeMinMs + evar.RespWinWidMs ;
  
  % Number of time bins
  C.N.time = numel( C.time ) ;
  
  % Size of time window for Fourier transform, in milliseconds
  C.N.win = 250 ;
  
  % fft interpolation, producing this many frequency bins
  C.N.fft = 1e3 ;
  
  % Hann window, apply to windowed time data for FFT
  C.hann = hann( C.N.win ) ;
  
  % FFT frequency bins, in Hz
  C.fft = ( 0 : C.N.fft - 1 ) * ( C.fs / C.N.fft ) ;
  
  % Maximum kept frequency bin, in Hz
  C.maxfreq = 100 ;
  
  % Logical index vector for kept frequency bins
  C.ifreq = C.fft <= C.maxfreq ;
  
  % Subset of frequency bins
  C.freq = C.fft( C.ifreq ) ;
  
  % Number of frequency bins
  C.N.freq = numel( C.freq ) ;
  
  % Time and frequency plot x-axis tick marks, in 100ms & 10Hz steps
  C.xtick.time = ceil( C.time(  1  ) / 100 ) * 100 : 100 : ...
                floor( C.time( end ) / 100 ) * 100 ;
  C.xtick.freq = ceil( C.freq(  1  ) / 10  ) * 10  : 10  : ...
                floor( C.freq( end ) / 10  ) * 10  ;

  % Spike train convolution kernel with 20ms time constant, millisecond
  % time bins
  C.kern = exp( - ( 0 : 255 )' ./ 20 ) ;
  C.kern = C.kern ./ sum( C.kern ) ;
  
  
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
  
  % Selection list box
  chlst = uicontrol( fh , 'Style' , 'listbox' , 'String' , ...
    arrayfun( @( i ) sprintf( 'Tdt Ch%d' , i ), 1 : C.N.chan,...
      'UniformOutput' , false ), 'Callback', @lstbox_cb, ...
        'UserData' , ofig , 'Tag', 'chansel' ) ;
  
  % Position box
  chlst.Units = 'normalized' ;
  chlst.Position( 3 ) = 1.1 * chlst.Position( 3 ) ;
  chlst.Position( 1 ) = 1 - chlst.Position( 3 ) ;
  chlst.Position( 2 ) = 0 ;
  chlst.Position( 4 ) = 1 ;
  
  % Get horizontal shift for data plots, in pixels
  chlst.Units = 'pixels' ;
  dx = chlst.Position( 3 ) / 2 ;
  
  
  %%% Create axes %%%
  
  % Subplot index initialised
  i = 0 ;

  % Data domains, & increment group index
  for  M = C.modality ; m = M{ 1 } ;
    
    % Data modalities, increment subplot index, make tag
    for  D = C.domain ; d = D{ 1 } ; i = i + 1 ; tag = [ m , d ] ;
      
      % Make new axes
      ax = ofig.subplot( C.N.modality , C.N.domain , i , ...
        'XTick' , C.xtick.( d ) , 'Units' , 'pixels' , 'XGrid' , 'on' , ...
          'Tag' , tag ) ;
      
      % Apply horizontal shift away from channel list box
      ax.Position( 1 ) = ax.Position( 1 ) - dx ;
      
      % Titles
      if     i == 1 , title( cfg.sessionName , 'Interpreter' , 'none' )
      elseif i == 2 , title( 'Avg. +/- SEM' )
      end
      
      % Clear x-tick labels on all but bottom plots, which have axis labels
      if  i  <  C.N.modality * C.N.domain - 1
        ax.XTickLabel = [] ;
      else
        xlabel( ax , L.X.( d ) )
      end
      
      % Set y-axis label on bottom plots
      ylabel( ax , [ L.Y.( d ) , m ] )
      
    end % modality
  end % domain
  
  
  %%% Colour name to RGB map %%%
  
  % Axes all have the same default ColorOrder set, point to one of them
  col = fh.Children( end ).ColorOrder ;
  
  % Define a struct mapping field names to corresponding RGB values
  col = struct( 'green' , col( 5 , : ) , ...
                 'blue' , col( 1 , : ) , ...
               'yellow' , col( 3 , : ) , ...
                 'plum' , col( 4 , : ) , ...
                'lgrey' , [ 0.6 , 0.6 , 0.6 ] ) ;
  
  % Map colours to target and laser types from table 'Target' and 'Laser'
  col.Target.none     = col.blue   ;
  col.Target.gaussian = col.green  ;
  col.Target.circle   = col.green  ;
  col.Target.bar      = col.green  ;
   col.Laser.none     = col.blue   ;
   col.Laser.test     = col.green  ;
   col.Laser.control  = col.yellow ;
   
   
  %%% Create graphics object groups %%%
  
  % Selection and unselection parameter indices
  isel = struct( 'Color' , 2 , 'LineWidth' , 4 , 'data' , 1 , 'error' , 2);
  
  % Selection and unselection parameter cell arrays. Outer cell is ordered
  % [ data , error bars ], inner cell contains parameters.
  selpar = { { 'Color' , col.blue , 'LineWidth' , 1.5 } ;
             { 'Color' , col.blue , 'LineWidth' , 0.5 , ...
               'Visible' , 'on' } } ;
  unspar = { { 'Color' , col.lgrey , 'LineWidth' , 0.5 } ;
             { 'Visible' , 'off' } } ;
           
  % NaN y-axis data for seeding graphics objects
  ynan.time = nan( C.N.time , 1 ) ;
  ynan.freq = nan( C.N.freq , 1 ) ;
  
  % Error bar x- and y-axis values
  err.x.time = [ C.time , NaN , C.time ] ;
  err.x.freq = [ C.freq , NaN , C.freq ] ;
  err.y.time = nan( size( err.x.time ) ) ;
  err.y.freq = nan( size( err.x.freq ) ) ;

	% Group data points to the same constants struct
  dat.C = C ;

  % Blocks of trials
  for  b = 1 : blk.N
    
    % Get block i.e. set identifier string
    nam = blk.nam{ b } ;

    % Find rows for this type of block
    r = tab.BlockType == blk.typ( b ) ;

    % Combine visual target and laser type in each row of table
    TL = crfc( @( T , L ) sprintf( '%s\n%s' , T , L ) , ...
      tab.Target( r ) , tab.Laser( r ) )' ;

    % Keep only unique combinations of target/laser types
    TL = unique( TL ) ;

    % Target/laser combinations, 
    for  TL = TL
      
      % Get target and laser type strings
      tl = strsplit( TL{ 1 } , '\n' ) ;
      [ target , laser ] = tl{ : } ;

      % Make group identifier string
      id = [ nam , ' ' , target , ' ' , laser ] ;
      
      % Initialise graphics handle vector, and cell vectors of parameters
      H = cell( 1 , C.N.modality * C.N.domain ) ;
      S = cell( 1 , C.N.modality * C.N.domain ) ;
      U = cell( 1 , C.N.modality * C.N.domain ) ;
      
      % Group index initialised
      i = 0 ;
      
      % Data modalities
      for  M = C.modality ; m = M{ 1 } ;
        
        % Data domains, & increment group index
        for  D = C.domain ; d = D{ 1 } ; i = i + 1 ;
          
          % Parent axes
          ax = findobj( fh , 'Type' , 'axes' , 'Tag' , [ m , d ] ) ;
          
          % Data will be a Welford array, for accumulating an estimate of
          % variance. Time/freq across rows, TDT channels across columns
          dat.( m ).( d ) = Welford( C.N.( d ) , C.N.chan ) ;

          % Create data and error graphics objects
          h = [ plot( ax , C.( d ) , ynan.( d ) , ...
                      'Tag' , [ m , d , 'data' ] ) , ...
                plot( ax , err.x.( d ) , err.y.( d ) , ...
                      'Tag' , [ m , d , 'error' ] ) ] ;

          % Set selection colours. Data shows laser, error shows target.
          selpar{ isel.data  }{ isel.Color } =  col.Laser.( laser  ) ;
          selpar{ isel.error }{ isel.Color } = col.Target.( target ) ;
          
          % Accumulate graphics objects and parameter settings
          H{ i } = h ;
          S{ i } = selpar ;
          U{ i } = unspar ;
          
        end % data domains
      end % data modalities
      
      % Concatenate group's graphics objects and parameter lists
      H = [ H{ : } ] ;  S = [ S{ : } ] ;  U = [ U{ : } ] ;
      
      % Add graphics object group and bind parameters
      ofig.addgroup ( id , nam , dat , H , @fupdate )
      ofig.bindparam( id ,   'seldata' , S{ : } )
      ofig.bindparam( id , 'unseldata' , U{ : } )
          
    end % target/laser combos
  end % blocks
  
  
  %%% Done %%%
  
  % Apply formatting through selection of first block, by default
  ofig.select( 'set' , ofig.grp( 1 ).set )
  
  % Show thine creations
  fh.Visible = 'on' ;
  
end % createphysfig


%%% Define data = fupdate( hdata , data , index , newdata ) %%%

% Note that the update function is only needed to accumulate new data.
% Refreshing the graphics objects is done by a call to the 'chansel' list
% box callback. Fourier transform taken from last C.N.win ms window of
% buffered data, unless a reaction time is given (non-empty); then it is
% last C.N.win ms before RT.
function  dat = fupdate( ~ , dat , ~ , rt )
  
  % Point to constants
  C = dat.C ;
  
  % Reaction time is not given.
  if  isempty( rt )  ||  ~ isscalar( rt )  ||  ~ isnumeric( rt )  ||  ...
      ~ isfinite( rt )
    
    % Take data up to the last time bin. No indexing required.
    rt = C.time( end ) ;
     i = [ ] ;
     
  % Reaction time provided
  else
    
    rt = floor( rt ) ; % Guarantee integer value.
    rt = max( rt , C.time( min( C.N.win + 1 , end ) ) ) ; %Guarantee min RT
    rt = min( rt , C.time( end ) ) ; % Guarantee maximum RT value.
     i = C.time < rt ; % Accumulate into a subset of Welford array.
     
  end % interpret rt input arg
  
  % Get milliseconds inside time window
  w = rt - C.N.win : rt - 1 ;
  
  % Subtract time of the last bin, to get ms from end of RT or buffer
  w = w  -  C.time( end ) ;
  
  % Add number of time bins to get linear indices of time bins in window
  w = w  +  C.N.time ;
  
  % Data modalities name, and channel starting index
  for  M = C.modality ; m = M{ 1 } ; ichan = C.ichan.( m ) ;
    
    % Get buffered time stamps (sec --> millisec) and data values
    T = C.buf.( m ).time .* 1e3 ;
    X = C.buf.( m ).data( : , ichan ) ;
    
    % TDT buffering error
    if  isempty( T ) || isempty( X )
      warning( 'TdtWinBuf %s retrieval error.' )
      continue
    end
    
    % Process data according to its modality
    switch  m
      
      % Spike times
      case  'spk'
        
        % First, allocate spike raster, ms time bins x channels
        R = zeros( C.N.time , C.N.chan ) ;
        
        % Channels
        for  ch = 1 : C.N.chan
          
          % Spike times
          t = T( X( : , ch ) > 0 ) ;
          
          % Convert from times to ms bin index
          t = ceil( ( t - C.time( 1 ) + 1 ) ) ;
          
          % Discard anything that falls off the edges
          t( t <= 0 | t > C.N.time ) = [ ] ;
          
          % No spikes, go to next channel
          if  isempty( t ) , continue , end
          
          % Raise raster time bins that contain a spike. Unit is spikes per
          % second.
          R( t , ch ) = 1e3 ;
          
        end % channels
        
        % Convolve spike raster with causal exponential kernel. This
        % function is available in the mak repository. It can be cloned in
        % a generic location such as C:\Toolbox\mak
        X = makconv( R , C.kern , 'c' ) ;
        
      % Continuous multiunit or local field potential activity
      case  { 'mua' , 'lfp' }
        
        % Linear interpolation at specified millisecond time bins
        X = interp1( T , X , C.time ) ;
        
    end % process neural data
    
    % Accumulate time series data into existing Welford array
    if  isempty( i )
      dat.( m ).time = dat.( m ).time  +  X ;
    else
      dat.( m ).time( i , : ) = dat.( m ).time( i , : )  +  X( i , : ) ;
    end
    
    % Windowed time domain data
    X = X( w , : ) ;
    
    % Find channels with finite values across all time bins
    j = all( isfinite( X ) , 1 ) ;
    
    % Remove DC component
    X = X - mean( X , 1 ) ;
    
    % Apply Hann window
    X = X  .*  C.hann ;
    
    % Get fourier transform, normalise by number of input samples, rather
    % than number of interpolated bins.
    X = fft( X , C.N.fft ) / C.N.win ;
    
    % Compute spectral magnitude
    X = 2 * abs( X ) ;
    
    % Accumulate spectral magnitude into Welford array
    dat.( m ).freq( : , j ) = dat.( m ).freq( : , j )  +  X( C.ifreq , j );
    
  end % data modalities
  
end % fupdate


%%% Channel selection callback %%%

% Load graphics objects with data from newly selected channel. Or refresh
% view of existing selection. Optional third input arg used to restrict
% update to a named of group.
function  lstbox_cb( lb , ~ , id )
  
  % TDT channel index
  ch = lb.Value ;
  
  % Point to onlinefigure object
  ofig = lb.UserData ;
  
  % Point to common constants
  C = ofig.grp( 1 ).data.C ;
  
  % Third input arg given. It is a classic string. Raise flag.
  idflg = nargin > 2  &&  ischar( id )  &&  isrow( id ) ;
  
  % Groups, supporting data, graphics objects
  for  grp = ofig.grp , dat = grp.data ; H = grp.hdata ;
    
    % Group id flag is high but group id does not match input arg
    if  idflg  &&  ~ strcmp( grp.id , id ) , continue , end
    
    % Data modalities
    for  M = C.modality ; m = M{ 1 } ;

      % Data domains
      for  D = C.domain ; d = D{ 1 } ;

        % Fetch Welford array
        w = dat.( m ).( d ) ;
        
        % Running average and standard error of mean
        a = w.avg( : , ch ) ;
        e = w.sem( : , ch ) ;
        
        % Find data line
        h = findobj( H , 'Tag' , [ m , d , 'data' ] ) ;
        
        % Switch/update channel mean value
        h.YData( : ) = transform( a , d ) ;
        
        % Find error bars
        h = findobj( H , 'Tag' , [ m , d , 'error' ] ) ;
        
        % Compute new mean +/- SEM values
        h.YData( : ) = transform( [ a + e ; NaN ; a - e ] , d ) ;

      end % domain
    end % modality
  end % groups
  
  %%% Sub-function %%%
  
  % If domain is time then a is returned. But if d is freq then dB is
  % computed, defined as 20log_10( a )
  function  a = transform( a , d )
    switch  d
      case 'time' , return
      case 'freq' , a = 20 * log10( a ) ;
                    a( isinf( a ) ) = NaN ;
    end
  end
  
end % lstbox_cb

