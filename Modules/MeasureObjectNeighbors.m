function handles = MeasureObjectNeighbors(handles)

% Help for the Measure Object Neighbors module:
% Category: Measurement
%
% Given an image with objects identified (e.g. nuclei or cells), this
% module determines how many neighbors each object has. The user
% selects the distance within which objects should be considered
% neighbors.
%
% How it works:
% Retrieves a segmented image of the objects, in label matrix format.
% The objects are expanded by the number of pixels the user specifies,
% and then the module counts up how many other objects the object
% is overlapping. Alternately, the module can measure the number of
% neighbors each object has if every object were expanded up until the
% point where it hits another object.  To use this option, enter 0
% (the number zero) for the pixel distance.  Please note that
% currently the image of the objects, colored by how many neighbors
% each has, cannot be saved using the SaveImages module, because it is
% actually a black and white image displayed using a particular
% colormap
%
% See also <nothing relevant>.

% CellProfiler is distributed under the GNU General Public License.
% See the accompanying file LICENSE for details.
%
% Developed by the Whitehead Institute for Biomedical Research.
% Copyright 2003,2004,2005.
%
% Authors:
%   Anne Carpenter <carpenter@wi.mit.edu>
%   Thouis Jones   <thouis@csail.mit.edu>
%   In Han Kang    <inthek@mit.edu>
%
% $Revision$


%

drawnow

%%%%%%%%%%%%%%%%
%%% VARIABLES %%%
%%%%%%%%%%%%%%%%



%%% Reads the current module number, because this is needed to find
%%% the variable values that the user entered.
CurrentModule = handles.Current.CurrentModuleNumber;
CurrentModuleNum = str2double(CurrentModule);

%textVAR01 = What did you call the objects whose neighbors you want to measure?
%infotypeVAR01 = objectgroup
ObjectName = char(handles.Settings.VariableValues{CurrentModuleNum,1});
%inputtypeVAR01 = popupmenu

%textVAR02 = Objects are considered neighbors if they are within this distance (pixels), or type 0 to find neighbors if each object were expanded until it touches others:
%defaultVAR02 = 0
NeighborDistance = str2num(handles.Settings.VariableValues{CurrentModuleNum,2});

%textVAR03 = If you are expanding objects until touching, what do you want to call these new objects?
%defaultVAR03 = ExpandedCells
%infotypeVAR03 = objectgroup indep
ExpandedObjectName = char(handles.Settings.VariableValues{CurrentModuleNum,3});

%textVAR04 = What do you want to call the image of the objects, colored by the number of neighbors?
%defaultVAR04 = ColoredNeighbors
%infotypeVAR04 = objectgroup indep
ColoredNeighborsName = char(handles.Settings.VariableValues{CurrentModuleNum,4});

%%%VariableRevisionNumber = 1

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% PRELIMINARY CALCULATIONS & FILE HANDLING %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
drawnow

%%% Reads (opens) the image you want to analyze and assigns it to a variable,
%%% "OrigImage".
fieldname = ['Segmented',ObjectName];
%%% Checks whether the image exists in the handles structure.
if ~isfield(handles.Pipeline,fieldname)
    error(['Image processing has been canceled. Prior to running the Measure Neighbors module, you must have previously run a segmentation module.  You specified in the MeasureObjectNeighbors module that the desired image was named ', IncomingLabelMatrixImageName(10:end), ', the Measure Neighbors module cannot locate this image.']);
end
IncomingLabelMatrixImage = handles.Pipeline.(fieldname);

%%%%%%%%%%%%%%%%%%%%%
%%% IMAGE ANALYSIS %%%
%%%%%%%%%%%%%%%%%%%%%



%%% Expands each object until almost 8-connected to its neighbors, if
%%% requested by the user.
if NeighborDistance == 0
    %%% The objects are thickened until they are one pixel shy of
    %%% being 8-connected.  This also turns the image binary rather
    %%% than a label matrix.
    ThickenedBinaryImage = bwmorph(IncomingLabelMatrixImage,'thicken',Inf);
    %%% The objects must be reconverted to a label matrix in a way
    %%% that preserves their prior labeling, so that any measurements
    %%% made on these objects correspond to measurements made by other
    %%% modules.
    ThickenedLabelMatrixImage = bwlabel(ThickenedBinaryImage);
    %%% For each object, one label and one label location is acquired and
    %%% stored.
    [LabelsUsed,LabelLocations] = unique(IncomingLabelMatrixImage);
    %%% The +1 increment accounts for the fact that there are zeros in the
    %%% image, while the LabelsUsed starts at 1.
    LabelsUsed(ThickenedLabelMatrixImage(LabelLocations(2:end))+1) = IncomingLabelMatrixImage(LabelLocations(2:end));
    FinalLabelMatrixImage = LabelsUsed(ThickenedLabelMatrixImage+1);
    IncomingLabelMatrixImage = FinalLabelMatrixImage;
    %%% The NeighborDistance is then set so that neighbors almost
    %%% 8-connected by the previous step are counted as neighbors.
    NeighborDistance = 4;
end


%%% Determines the neighbors for each object.
d = max(2,NeighborDistance+1);
[sr,sc] = size(IncomingLabelMatrixImage);
ImageOfNeighbors = -ones(sr,sc);
NumberOfNeighbors = zeros(max(IncomingLabelMatrixImage(:)),1);
IdentityOfNeighbors = cell(max(IncomingLabelMatrixImage(:)),1);
se = strel('disk',d,0);
props = regionprops(IncomingLabelMatrixImage,'PixelIdxList');
for k = 1:max(IncomingLabelMatrixImage(:))
    % Cut patch
    [r,c] = ind2sub([sr sc],props(k).PixelIdxList);
    rmax = min(sr,max(r) + (d+1));
    rmin = max(1,min(r) - (d+1));
    cmax = min(sc,max(c) + (d+1));
    cmin = max(1,min(c) - (d+1));
    p = IncomingLabelMatrixImage(rmin:rmax,cmin:cmax);
    % Extend cell boundary
    pextended = imdilate(p==k,se,'same');
    overlap = p.*pextended;
    IdentityOfNeighbors{k} = setdiff(unique(overlap(:)),[0,k]);
    NumberOfNeighbors(k) = length(IdentityOfNeighbors{k});
    ImageOfNeighbors(sub2ind([sr sc],r,c)) = NumberOfNeighbors(k);
end

%%% Calculates the ColoredLabelMatrixImage for displaying in the figure
%%% window and saving to the handles structure.
%%% Note that the label2rgb function doesn't work when there are no objects
%%% in the label matrix image, so there is an "if".
%%% Note: this is the expanded version of the objects, if the user
%%% requested expansion.

if sum(sum(IncomingLabelMatrixImage)) >= 1
    cmap = jet(max(64,max(IncomingLabelMatrixImage(:))));
    ColoredLabelMatrixImage = label2rgb(IncomingLabelMatrixImage,cmap, 'k', 'shuffle');
else  ColoredLabelMatrixImage = IncomingLabelMatrixImage;
end

%%% Does the same for the ImageOfNeighbors.  For some reason, this
%%% does not exactly match the results of the display window. Not sure
%%% why.
if sum(sum(ImageOfNeighbors)) >= 1
    ColoredImageOfNeighbors = ind2rgb(ImageOfNeighbors,[0 0 0;jet(max(ImageOfNeighbors(:)))]);
else  ColoredImageOfNeighbors = ImageOfNeighbors;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% MAKE MEASUREMENTS & SAVE TO HANDLES STRUCTURE %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
drawnow



%%% Saves neighbor measurements to handles structure.
handles.Measurements.(ObjectName).NumberNeighbors(handles.Current.SetBeingAnalyzed) = {NumberOfNeighbors};
handles.Measurements.(ObjectName).NumberNeighborsFeatures = {'Number of neighbors'};

% This field is different from the usual measurements. To avoid problems with export modules etc we don't
% add a IdentityOfNeighborsFeatures field. It will then be "invisible" to
% export modules, which look for fields with 'Features' in the name.
handles.Measurements.(ObjectName).IdentityOfNeighbors(handles.Current.SetBeingAnalyzed) = {IdentityOfNeighbors};


%%% Example: To extract the number of neighbor for objects called Cells, use code like this:
%%% handles.Measurements.Cells.IdentityOfNeighborsCells{1}{3}
%%% where 1 is the image number and 3 is the object number. This
%%% yields a list of the objects who are neighbors with Cell object 3.

%%%%%%%%%%%%%%%%%%%%%%
%%% DISPLAY RESULTS %%%
%%%%%%%%%%%%%%%%%%%%%%
drawnow

fieldname = ['FigureNumberForModule',CurrentModule];
ThisModuleFigureNumber = handles.Current.(fieldname);
if any(findobj == ThisModuleFigureNumber) == 1
    FontSize = handles.Current.FontSize;
    %%% Sets the width of the figure window to be appropriate (half width).
    if handles.Current.SetBeingAnalyzed == handles.Current.StartingImageSet
        originalsize = get(ThisModuleFigureNumber, 'position');
        newsize = originalsize;
        newsize(3) = 0.5*originalsize(3);
        set(ThisModuleFigureNumber, 'position', newsize);
    end
    drawnow

    CPfigure(handles,ThisModuleFigureNumber);
    subplot(2,1,1)
    imagesc(ColoredLabelMatrixImage)
    title('Cells colored according to their original colors','FontSize',FontSize)
    set(gca,'FontSize',FontSize)
    subplot(2,1,2)
    imagesc(ImageOfNeighbors)
    colorbar('SouthOutside','FontSize',FontSize)
    title('Cells colored according to the number of neighbors','FontSize',FontSize)
    set(gca,'FontSize',FontSize)
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% SAVE IMAGES TO HANDLES STRUCTURE %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%% To make this module produce results similar to an IdentifyPrim
%%% module, we will save the image IncomingLabelMatrixImage (which may
%%% have been expanded until objects touch) to the handles
%%% structure, even though the editing for size and for edge-touching
%%% has not been performed in this module's case.

%%% Saves the segmented image, not edited for objects along the edges or
%%% for size, to the handles structure.
fieldname = ['UneditedSegmented',ExpandedObjectName];
handles.Pipeline.(fieldname) = IncomingLabelMatrixImage;

%%% Saves the segmented image, only edited for small objects, to the
%%% handles structure.
fieldname = ['SmallRemovedSegmented',ExpandedObjectName];
handles.Pipeline.(fieldname) = IncomingLabelMatrixImage;

%%% Saves the final segmented label matrix image to the handles structure.
fieldname = ['Segmented',ExpandedObjectName];
handles.Pipeline.(fieldname) = IncomingLabelMatrixImage;

%%% Saves the colored version of images to the handles structure so
%%% they can be saved to the hard drive, if the user requests.
fieldname = ['Colored',ExpandedObjectName];
handles.Pipeline.(fieldname) = ColoredLabelMatrixImage;
fieldname = ['Colored',ColoredNeighborsName];
handles.Pipeline.(fieldname) = ColoredImageOfNeighbors;
