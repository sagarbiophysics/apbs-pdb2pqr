function [] = MAPBS(inputfile)
clc
%% MATLAB version of the PB solver

% THIS CODE IS BASED ON THE HOLST ARTICLE AND THE APBS ALGORITHM. IT
% BASICALLY SOLVES THE LINEARIZED PB EQUATION AND THEN SAVE THE SOLUTION 
% AND THE CHARGE DISTRIBUTION MAPS IN DX FORMAT. 


% WARNING!!!!!!!!!!!!!!! BEFORE USING IT: 

% FIRST STEP:

% YOU WILL NEED THE FOLLOWING INPUT FILES from the APBS and PDBTOPQR:
% THE PQR FILEs.
% THE DX FILES CORRESPONDING TO THE SHIFTED DIELECTRIC COEFFICIENTS
% AS GENERATED BY THE APBS CODE.
% THE DX FILE CORRESPONDING TO THE KAPPA COEFFICIENTS AS GENERATED BY THE
% APBS CODE.
% THE .INM FILE WHICH IS THE MAIN INPUT FILE OF THIS CODE.

%SECOND STEP:

% YOU HAVE TO CREATE THE .INM INPUT FILE

% The .inm file parsing is strict.
% input must contain the value of these parameters in exactly this order in a column:
% dime   
% glen   
% T
% I ew
% bc
% digpres
% dielx_str
% diely_str
% dielz_str
% kappa_str
% pqr_str
% pqr_cent_str
% in_name_str
% name_str

% Just one inm. file is required if the user is not using focus boundary
% condition as you can see in the following example:

%|--example solvated-born.inm file using Dirichlet Boundary Condition--|

% 65 65 65               % Number of grid points (AS IN APBS CODE)
% 12 12 12              % in Amstrongs (AS IN APBS CODE)
% 298.15                    % Tempature in Kelvin
% 0.0 78.54            % [ionic_strength(=0.5*sum(c_i*z_i^2)) solvent_dielectric_coeffient] 
% sdh               % It uses Dirichlet boundary condition
% 6    % significant digits of precision in teh solution for the elect pot (residual error)
% solvated-born-dielx.dx       % Filename of input data
% solvated-born-diely.dx
% solvated-born-dielz.dx
% solvated-born-kappa.dx
% born-ion.pqr     % (pqr file name of the molecule I will calculate the elect potential)
% born-ion.pqr     % (pqr file name of the molecule I will calculate the center of grid)
% c:\Users\Marce\Matlab_work_space\Input_Files  %(full path input files)
% c:\Users\Marce\Matlab_work_space\born_model  %(full path output files)

%|------------

% Otherwise, two inm. files are required if the user use the focus boundary
% condition as you can see in the following example:

%|--example solvated-born.inm file using focus boundary condition--|

% 65 65 65               % Number of grid points (AS IN APBS CODE)
% 12 12 12              % in Amstrongs (AS IN APBS CODE)
% 298.15                    % Tempature in Kelvin
% 0.0 78.54            % [ionic_strength(=0.5*sum(c_i*z_i^2)) solvent_dielectric_coeffient] 
% focusname.inm   % it use focus bound cond. (see example of this file below)
% 6    % significant digits of presion in teh solution for the elect pot (residual error)
% solvated-born-dielx.dx       % Filename of input data
% solvated-born-diely.dx
% solvated-born-dielz.dx
% solvated-born-kappa.dx
% born-ion.pqr     % (pqr file name of the molecule I will calculate the elect potential)
% born-ion.pqr     % (pqr file name of the molecule I will calculate the center of grid)
% c:\Users\Marce\Matlab_work_space\Input_Files  %(full path input files target grid)
% c:\Users\Marce\Matlab_work_space\target_born_model  %(full path output files)

%|-------------------
  
%|--example focusname.inm file for the calculation of the elect pot in the coarse grained calculation 

% 45 45 45               % Number of grid points (AS IN APBS CODE)
% 50 50 50              % in Amstrongs (AS IN APBS CODE)
% 298.15                    % Tempature in Kelvin
% 0.0 78.54            % [ionic_strength(=0.5*sum(c_i*z_i^2)) solvent_dielectric_coeffient] 
% sdh                 % it uses Dirichlet boundary condition
% 6    % significant digits of presion in teh solution for the elect pot (residual error)
% coarse-born-dielx.dx       % Filename of input data
% coarse-born-diely.dx
% coarse-born-dielz.dx
% coarse-born-kappa.dx
% born-ion.pqr     % (pqr file name of the molecule I will calculate the elect potential)
% complex.pqr     % (pqr file name of the molecule I will calculate the center of grid)
% c:\Users\Marce\Matlab_work_space\Input_Files  %(full path input files coarse grain calculation)
% c:\Users\Marce\Matlab_work_space\coarse_born_model  %(full path output files)

%|--------------------|

% YOU ARE DONE. NOW YOU ARE READY TO USE THIS CODE!!!!!! THANKS !!!!

% CALLED MATLAB FILES: 
% read_inm.m (read the input file)
% data_parse.m (To read dx files and convert them to data arrays)
% BoundaryCondition.m (To evaluate the dirichlet boundary condition along the
% 6 faces)
% BuildA.m (construction of A matrix and b columm vector)
% dx_export.m (To convert data arrays to dx format)
% discretization.m (To spread the point-like charges around the nearest grid
% points.)
% parameters.m (evaluation of the parameters involved in the calculations)
% centerofgrid.m (evaluation of the center of grid from the pqr files)
% fbc.m (focus boundary condition. It use linear interpolation approach to
               % evalaute dirichlet boundary condition in the target grid from the
               % solution of the elect pot obtrained in the coarse grain)

%% Part 1.  Read the data
 
% read the .inm file and display it in the matlab cmd

 [dime, glen, T, bulk, bc, digpres, dielx_str, diely_str, dielz_str, kappa_str, pqr_str,pqr_cent_str,in_nam_str, nam_str] = read_inm(inputfile);
 addpath(in_nam_str)
% creating the file which will contain all messages printed on the screen
diary ('MATLAB_screen.io')

disp('Welcome!!!!!!....')
disp(' ')
disp('This code will solve the PB equation')
disp('to obtain an approximate solution for the electrostatic potential')
disp('for the model defined in the following input file')
disp(inputfile)
disp(' ')
% if we use focus boundary condition, numgrid=1 evaluates the elect pot in
% the coarse grain and numgrid=2 is used to evaluate the boundary
% condition for the fine grid and to obtain the solution in a subdomain. 
% If we use just one grid, then bc=sdh, numgrid=1 refers to the fine
% grid and the numgrid=2 is not used.

for numgrid=1:2

% evaluating parameters such as zmagic, debye constant, kappa, thermal unit, etc.
run parameters

% defining the name of the input files depending the working size of the grid.

if strcmp(bc, 'focusname.inm')==1
    plotname='coarse_grid_MATLAB_pot';
    outputfile='coarse_grid_MATLAB_pot.dx';
    outputfile2='coarse_grid_MATLAB_rho.dx';
% let's make a copy of the input file in the current directory. It is needed
% if the focus boundary condition is required. 
 copyfile(inputfile,'copyinputfile.inm');
else
    outputfile='target_grid__MATLAB_pot.dx';
    outputfile2='target_grid_MATLAB_rho.dx';
    plotname='target_grid_MATLAB_pot';
end

% If bc=sdh it mean I am in the fine grid and I have to do nothing. Otherwise
% I have to read the focusname.inm to get the grid data and iput files 
% to evaluate the elec pot in the coarse grid.


if strcmp(bc, 'sdh')==0
    oldbc=bc;
    [dime, glen, T, bulk, bc,digpres,dielx_str, diely_str, dielz_str, kappa_str, pqr_str,pqr_cent_str,in_nam_str,nam_str] = read_inm(bc);
%    disp('Calculating')
disp('Coarse grained calculation')
disp(' ')
addpath(in_nam_str)
end
disp('Reading the input files')
% read the .dx files
dielx=data_parse(dielx_str, dime);
diely=data_parse(diely_str, dime);
dielz=data_parse(dielz_str, dime);
kappa=data_parse(kappa_str, dime);
dime
glen
disp('Done!....')
disp(' ')

% find the spatial step sizes in each dimension h

for dimension=1:3
  h(dimension)=glen(dimension)/(dime(dimension)-1);  
end

%% Part 2.  solve A*pot=b

tic

% evaluating the center of grid from the pqr files
run centerofgrid

disp('Calculating boundary condition....')

% for either bc=focusname.inm or sdh we should first evaluate dirichlet bond cond. 
% In the former it is on the corase grid and the latter on the fine grid.
% Therefore, for numgrid= I have to run BoundaryCondition.
% If bc=sdh then I exit at the end without using numgrid=1. Otherwise
% I have to run FocusBoundaryCondition to evalaute the Dirichlet bound cond
% using the elec pot solution from the coarse grain grid obtained
% previously.

if numgrid==1
run BoundaryCondition
%change the assigned value for bc in order to go to the fine grid
%calcualtion
bc='coarse';
else 
run fbc
end

disp('Done!....')
disp(' ')
%Discretization charge density

disp('Generating the charge map....')

run discretization

disp('Done!....')
disp(' ')

%difining the vector needed for the export.m file
rmin=[xmin ymin zmin];

% Prepare the Laplacian operator A and b

disp('Constructing the sparse matrix A....')

run BuildA

disp('Done!....')
disp(' ')

% Solve A*pot=b using the biconjugate gradients stabilized method

disp('Performing the LU decomposition....')

tolerance=0.25;
[L U]=luinc(A,tolerance);

disp('Done!....')
disp(' ')

disp('Solving the linear equation system using the')

disp('Biconjugated gradient method stabilized by LU matrices')


accuracy=10^-(digpres);
max_iteration=800;
[pote,flag,relres,iter]=bicgstab(A,bb,accuracy, max_iteration,L,U);

if flag ~= 0
disp('The solver was reach the desired accuracy....') 
disp('please change the tolerance and or the')
disp('number of maximum iteration and try it again')
flag
iter
relres
return
end
error=relres
iteration_number=iter
disp('Done!....')
disp(' ')
% Add Boundary to Solution

potc=zeros(dime(1)-2,dime(2)-2,dime(3)-2);

for i=2:dime(1)-1
    for j=2:dime(2)-1
        for k=2:dime(3)-1
             pe=(k-2)*(dime(1)-2)*(dime(2)-2)+(j-2)*(dime(1)-2)+i-1;
             potc(i,j,k)=pote(pe);
        end
    end
end

% solution

% adding Boundary condition
MATLAB_pot=potB;

% adding the solution of the linear equation
MATLAB_pot(2:dime(1)-1,2:dime(1)-1,2:dime(1)-1)=potc(2:dime(1)-1,2:dime(1)-1,2:dime(1)-1);

computing_time=toc

%% Part 3: Write out the electrostatic potential in dx format

%let's create the folder "outputfiles" in the output path directory
dirname='outputfiles';
mkdir(nam_str,dirname)

% checking if the user is working on a pc o unix platarform
kt = strfind(nam_str, '/');
if numel(kt)>0 
    outpath=strcat(nam_str,'/',dirname);
else
    outpath=strcat(nam_str,'\',dirname);
end

disp('Converting to dx format...')

% electrostatic potential solution

dxformat=MATLAB_pot;
namefile='POTENTIAL (KT/e)';
run dx_export
disp(['the file ' outputfile ' was generated'])

% let's create a copy of the matlab solution which is required for the
% focus boundaary condition as the input file below
if numgrid ==1
copyfile(outputfile,'MATLAB_Solution.dx');
%copyfile(outputfile,'C:\Users\Marce\Documents\temp\MATLAB_PB_SOLVER_4\Potential')
else
%    copyfile(outputfile,'C:\Users\Marce\Documents\temp\MATLAB_PB_SOLVER_4\Potential2')
end
movefile (outputfile, outpath)
% charge map

dxformat=charge;
namefile='CHARGE DENSITY (e/A^3)';
outputfile=outputfile2;
run dx_export
disp(['the file ' outputfile ' was generated'])
movefile (outputfile, outpath)
disp('Done!')
disp(' ')
%% Part 4: Generating the surface Plots

disp('Generating plots!....')

% surface defined by z=33
n=(dime(3)+1)/2;

figure

%plotting the electrostatic potential solutions
name2= plotname;
plot2=surf(MATLAB_pot(:,:,n),'facecolor','interp');
% I do not want MATLAB to create a figure
% get(0,'CurrentFigure')
saveas(plot2,name2,'fig');
disp(['the file ' name2 '.fig was generated'])
movefile (strcat(name2,'.fig'), outpath)
saveas(plot2,name2,'jpg');
disp(['the file ' name2 '.jpg was generated'])
movefile (strcat(name2,'.jpg'), outpath)
pause (3)
close
disp('Done!....')
disp(' ')

% If bc=focusname.inm then It means that I already evalaute the elect pot
% in the coarse grid and now i have to read the input files to evalaute the
% elec pot in the fine grid. If bc=sdh it means that I am done and I must
% exit.
if strcmp(bc, 'sdh')==0
%disp('close the figure window and then press enter to continue..')
%disp(' ')
pause (3)
clear
disp('Calculating')
disp('the electrostatic potential in the target grid....')
disp(' ')
% MYPATH='C:\Users\Marce\Documents\temp\Input_Files';
%  addpath(MYPATH)
 inputfile='copyinputfile.inm';
 disp('reading the solution obtained previously in the coarse grid....')
disp(' ')
 [rminn,cgdime,cgh]=gridinf('MATLAB_Solution.dx');
 MATLAB_pot_coarse=data_parse('MATLAB_Solution.dx', cgdime);
 disp(' ')
     [dime, glen, T, bulk, bc, digpres, dielx_str, diely_str, dielz_str, kappa_str, pqr_str,pqr_cent_str,in_nam_str,nam_str] = read_inm(inputfile);
     bc='sdh';
     delete('copyinputfile.inm');
%     cgh=h;
%     cgdime=dime;
%     cgglen=glen;
addpath(in_nam_str)
else
    break
end
end
disp('Thanks for using our PB solver!!!!....')
diary off
movefile ('MATLAB_screen.io', outpath)
delete('MATLAB_Solution.dx')
clear all
end