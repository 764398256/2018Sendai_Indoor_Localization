function [distance, n] = getDistance(experiment, n_init, beta)
    % VARIABLES
    %   experiment:          Experiment data structure as generated by
    %                        getExperimentData().
    %   n_init:              (optional) Initial path loss exponent.
    %   beta:                (optional) Rate of change parameter that
    %                        controls how much path loss exponent can
    %                        change when a jump occurs.  E.g. 1/10 means a 
    %                        jump of 10dBm will correspond to a jump of 1 in 
    %                        the exponent.
    %
    % Outputs the distance from AP at each point. See equation (6) in 
    % "A Survey of Selected Indoor Positioning Method for Smartphones"
    % by Davidson et al for details.
    
    if nargin < 3
        if nargin < 2
            n_init = 8;
        end
        beta = 1/60;
    end


    Tx = 10;        % Transmission power at 10 dBm
    f = 2.4*10^9;   % Uses a 2.4 GHz WLAN channel
    c = 299792458;  % Speed of light;
    
    filtered_signal = experiment.filtered;
    jumpLocs = experiment.jumps;
    
    % Basically think about the path-loss exponent as a function
    % on the indices. We'll start off with n=4.
    n = zeros(size(filtered_signal));
    if ~isempty(jumpLocs)
        n(1:jumpLocs(1,1)) = n_init;
    else
        % No jumps! n is constant!
        n(1:end) = n_init;
    end
    for i=1:size(jumpLocs,1)
        start = jumpLocs(i,1);
        stop = jumpLocs(i,2);
        
        % Where our path loss exponent left off.
        startn = n(max(start-1,1));
        
        % Calculate how much RSS jumps and find out how
        % much the path loss exponent should change after
        % the jump.
        dRSS = filtered_signal(stop) - filtered_signal(start);
        stopn = min(max(startn - beta*dRSS, 2),20);

        % Interpolate between startn and stopn based proportions of
        % the total variation of the jump.
        local_deriv = diff(filtered_signal(start:stop));
        TV = sum(abs(local_deriv));
        props = (1/TV)*abs(local_deriv);
        [g,z] = ecdf(props);
        n(start:stop) = startn + (stopn - startn)*g;
        %n(start:stop) = stopn;
        
        % Fill in n after this jump.
        if i < size(jumpLocs,1)
            n((stop+1):jumpLocs(i+1,1)) = stopn;
        else
            n(min((stop+1),end):end) = stopn;
        end

    end
   
    % Now just use equation (6) from Davidson paper!
    distance = 10.^((Tx-filtered_signal)./(10*n));
end