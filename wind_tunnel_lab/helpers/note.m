function note(varargin)
%NOTE Print an assumption / flag line in the command window.
fprintf(['  NOTE: ' varargin{1} '\n'], varargin{2:end});
end
