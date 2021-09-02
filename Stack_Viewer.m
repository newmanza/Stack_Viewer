%TODO List
%Flag Frames add to traces
%depth color
%delete/Undo ROI Area MOD NOT WORKING
%export image
%autocontrast
%line profilesExpo
%Auto-Tag Localizations
%Add Localization Counts to Trace
%LogHistY Zero adjust
%profile max proj
%orthogoal projections
%orthognal profiles
%RGB Mask Overlay Transparency
% frame buffer fast forward and pre-render
function varargout=Stack_Viewer(varargin)
% Stack_Viewer Zachary Newman's Implementation of many ImageJ tools in Matlab
% [ViewerFig,Channel_Info,ImagingInfo,OutputAnalysis,ImageArray] = ...
%   Stack_Viewer(ImageArray,DataRegion,StackOrder,Channel_Labels,Channel_Colors,Channel_Info,ImagingInfo,SaveName,InputAnalysis,EditRecord,ReleaseFig)
% A fully featured UI to view various types of data including 3D multi
% color images or time series or even multi-channel time series
% DataRegion is either a single 2D image or a ImageArray-dimension matched logical array corresponding to any releavent data mask
% to show the ABSENSE of imaging information, either due to tiling/stitching or analysis of speciric regions
% ImageArray currently supports the following image formats
% (Use these formats for the StackOrder input)
% 3D: 'YXT';'YXZ';'YXC'
% 4D: 'YXZT';'YXTZ';'YXCT';'YXTC';'YXZC';'YXCZ';'YX[RGB]T';'YXT[RGB]'
% 5D: 'YXTZC','YXZTC'
% Channel_Labels and Channel_Colors are cell arrays that must have the same number of dimesions as the C dim
% ImagingInfo is looking for the following fields:
%   ImagingInfo.PixelSize=0.21;
%   ImagingInfo.PixelUnit='um';
%   ImagingInfo.VoxelDepth=0.5;
%   ImagingInfo.VoxelUnit='um';
%   ImagingInfo.InterFrameTime=50;
%   ImagingInfo.FrameUnit='ms';
% InputAnalysis/OutputAnalysis will be structures containing various features that can be analyzed within this script
%
% Ouput of the ViewerFig can allow other scritps to monitor the closing of
% Stack Viewer. Similarly the ReleaseFig input is a logical that will
% either release the ViewerFig export if 1 or retain the ViewerFig Handle
% and apply a uiwait to prevent progressing after the function
% Lack of any input will initiate Stack_Import and offer to save the data
% as well.
% Dependencies: Bioformats export_fig

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    disp('=============================================================================================');
    disp('=============================================================================================');
    fprintf('Initializing Stack Viewer...\n')
    warning on all
    warning off verbose
    warning off backtrace
    MatlabVersion=version('-release');
    MatlabVersionYear=MatlabVersion(1:4);
    try 
        ParallelToolBoxVersion=ver('parallel');
        ParallelProcessingAvailable=1;
        ParallelProcessing=[];
    catch
        ParallelProcessingAvailable=0;
        ParallelProcessing=0;
    end
    myPool=[];
    OS=computer;
    if strcmp(OS,'MACI64')
        dc='/';
    else
        dc='\';
    end
    [ret, compName] = system('hostname');   
    if ret ~= 0
       if ispc
          compName = getenv('COMPUTERNAME');
       else      
          compName = getenv('HOSTNAME');      
       end
    end
    compName = lower(compName);
    compName=cellstr(compName);
    compName=compName{1};
    ScreenSize=get(0,'ScreenSize');
    ExitViewer=0;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Check for depenedencies
    if ~exist('imreadbf.m')
        error('Please Install OME-Bioformats https://docs.openmicroscopy.org/bio-formats/6.1.0/users/matlab/index.html')
    end
    if ~exist('export_fig.m')
        error('Please Install export_fig.m https://www.mathworks.com/matlabcentral/fileexchange/23629-export_fig')
    end
    if ~exist('subtightplot.m')
        error('Please Install subtightplot.m https://www.mathworks.com/matlabcentral/fileexchange/39664-subtightplot')
    end
    if ~exist('makeColorMap.m')
        error('Please Install makeColorMap.m https://www.mathworks.com/matlabcentral/fileexchange/17552-makecolormap')
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    StartingDir=cd;
    ExportDir=[];
    Save2Scratch=0;
    ScratchDir=[];
    RawDataDir=[];
    FileID=[];
    FileName=[];
    global ImageArray
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Parse Inputs
    if nargin==0
        StackOrder=[];
        Channel_Labels=[];
        Channel_Colors=[];
        Channel_Color_Codes=[];
        Channel_Info=[];
        [FileID,FileName,RawDataDir,ScratchDir,ImageArray,DataRegion,StackOrder,...
            MetaData,Additional_MetaData,BasicFileData,...
            Channel_Labels,Channel_Colors,Channel_Color_Codes]=Stack_Import;
           
        SaveImportChoice = questdlg({'Save imported data for?';[FileName]},'Save Imported Data?','Save','Skip','Save');
        switch SaveImportChoice
            case 'Save'
                SaveImport=1;
            case 'Skip'
                SaveImport=0;
        end
        if strcmp(RawDataDir,ScratchDir)
            Save2Scratch=0;
        elseif isempty(ScratchDir)
            Save2Scratch=0;
        else
            Save2Scratch=1;
        end
        if SaveImport
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            InitializeDir
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            ImportFileName=[FileID,' Imported Data.mat'];
            if Save2Scratch
                fprintf(['Saving: ',ImportFileName,' to ScratchDir...'])
                save([ScratchDir,dc,ImportFileName],'ImageArray','DataRegion','StackOrder','MetaData','Additional_MetaData','BasicFileData','FileID','FileName','Channel_Labels','Channel_Colors','Channel_Color_Codes','Channel_Info')
                fprintf(['Copying ',ImportFileName,' To Final ExportDir...'])
                [CopyStatus,CopyMessage]=copyfile([ScratchDir,dc,ImportFileName],ExportDir);
                if CopyStatus
                    fprintf('Copy successful!')
                    warning('Deleting ScratchDir Version')
                    recyclestate = recycle;
                    switch recyclestate
                        case 'off'
                            recycle('on');
                            delete([ScratchDir,dc,ImportFileName]);
                            recycle('off');
                        case 'on'
                            delete([ScratchDir,dc,ImportFileName]);
                    end
                else
                    warning(CopyMessage)
                end
            else
                fprintf(['Saving: ',ImportFileName,' to RawDataDir...'])
                save([RawDataDir,dc,ImportFileName],'ImageArray','DataRegion','StackOrder','MetaData','Additional_MetaData','BasicFileData','FileID','FileName')
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            cd(RawDataDir)
        end
        if ~isempty(DataRegion)
            DataRegionMaskOn=1;
            DataRegionBorderOn=1;
            [DataRegionBorderLine]=FindROIBorders(DataRegion,1);
        else
            DataRegionMaskOn=0;
            DataRegionBorderOn=0;
            DataRegionBorderLine=[];
        end
        MetaData
        ImagingInfo.PixelSize=MetaData.ScalingX;
        ImagingInfo.PixelUnit='um';
        ImagingInfo.VoxelDepth=MetaData.ScalingZ;
        ImagingInfo.VoxelUnit='um';
        ImagingInfo.InterFrameTime=MetaData.ScalingT;
        ImagingInfo.FrameUnit='s';
        SaveName=FileID;
        InputAnalysis=[];
        ReleaseFig=0;
    elseif nargin==1
        ImageArray=varargin{1};
        DataRegionMaskOn=0;
        DataRegionBorderOn=0;
        DataRegion=[];
        DataRegionBorderLine=[];
        StackOrder=[];
        Channel_Labels=[];
        Channel_Colors=[];
        Channel_Info=[];
        ImagingInfo=[];
        SaveName=[];
        InputAnalysis=[];
        ReleaseFig=0;
    elseif nargin==2
        ImageArray=varargin{1};
        DataRegion=varargin{2};
        if ~isempty(DataRegion)
            DataRegionMaskOn=1;
            DataRegionBorderOn=1;
            [DataRegionBorderLine]=FindROIBorders(DataRegion,1);
        else
            DataRegionMaskOn=0;
            DataRegionBorderOn=0;
            DataRegionBorderLine=[];
        end
        StackOrder=[];
        Channel_Labels=[];
        Channel_Colors=[];
        Channel_Info=[];
        ImagingInfo=[];
        SaveName=[];
        InputAnalysis=[];
        ReleaseFig=0;
    elseif nargin==3
        ImageArray=varargin{1};
        DataRegion=varargin{2};
        if ~isempty(DataRegion)
            DataRegionMaskOn=1;
            DataRegionBorderOn=1;
            [DataRegionBorderLine]=FindROIBorders(DataRegion,1);
        else
            DataRegionMaskOn=0;
            DataRegionBorderOn=0;
            DataRegionBorderLine=[];
        end
        StackOrder=varargin{3};
        Channel_Labels=[];
        Channel_Colors=[];
        Channel_Info=[];
        ImagingInfo=[];
        SaveName=[];
        InputAnalysis=[];
        ReleaseFig=0;
    elseif nargin==4
        ImageArray=varargin{1};
        DataRegion=varargin{2};
        if ~isempty(DataRegion)
            DataRegionMaskOn=1;
            DataRegionBorderOn=1;
            [DataRegionBorderLine]=FindROIBorders(DataRegion,1);
        else
            DataRegionMaskOn=0;
            DataRegionBorderOn=0;
            DataRegionBorderLine=[];
        end
        StackOrder=varargin{3};
        Channel_Labels=varargin{4};
        Channel_Colors=[];
        Channel_Info=[];
        ImagingInfo=[];
        SaveName=[];
        InputAnalysis=[];
        ReleaseFig=0;
    elseif nargin==5
        ImageArray=varargin{1};
        DataRegion=varargin{2};
        if ~isempty(DataRegion)
            DataRegionMaskOn=1;
            DataRegionBorderOn=1;
            [DataRegionBorderLine]=FindROIBorders(DataRegion,1);
        else
            DataRegionBorderLine=[];
        end
        StackOrder=varargin{3};
        Channel_Labels=varargin{4};
        Channel_Colors=varargin{5};
        Channel_Info=[];
        ImagingInfo=[];
        SaveName=[];
        InputAnalysis=[];
        ReleaseFig=0;
    elseif nargin==6
        ImageArray=varargin{1};
        DataRegion=varargin{2};
        if ~isempty(DataRegion)
            DataRegionMaskOn=1;
            DataRegionBorderOn=1;
            [DataRegionBorderLine]=FindROIBorders(DataRegion,1);
        else
            DataRegionMaskOn=0;
            DataRegionBorderOn=0;
            DataRegionBorderLine=[];
        end
        StackOrder=varargin{3};
        Channel_Labels=varargin{4};
        Channel_Colors=varargin{5};
        Channel_Info=varargin{6};
        ImagingInfo=[];
        SaveName=[];
        InputAnalysis=[];
        ReleaseFig=0;
    elseif nargin==7
        ImageArray=varargin{1};
        DataRegion=varargin{2};
        if ~isempty(DataRegion)
            DataRegionMaskOn=1;
            DataRegionBorderOn=1;
            [DataRegionBorderLine]=FindROIBorders(DataRegion,1);
        else
            DataRegionMaskOn=0;
            DataRegionBorderOn=0;
            DataRegionBorderLine=[];
        end
        StackOrder=varargin{3};
        Channel_Labels=varargin{4};
        Channel_Colors=varargin{5};
        Channel_Info=varargin{6};
        ImagingInfo=varargin{7};
        SaveName=[];
        InputAnalysis=[];
        ReleaseFig=0;
    elseif nargin==8
        ImageArray=varargin{1};
        DataRegion=varargin{2};
        if ~isempty(DataRegion)
            DataRegionMaskOn=1;
            DataRegionBorderOn=1;
            [DataRegionBorderLine]=FindROIBorders(DataRegion,1);
        else
            DataRegionMaskOn=0;
            DataRegionBorderOn=0;
            DataRegionBorderLine=[];
        end
        StackOrder=varargin{3};
        Channel_Labels=varargin{4};
        Channel_Colors=varargin{5};
        Channel_Info=varargin{6};
        ImagingInfo=varargin{7};
        SaveName=varargin{8};
        InputAnalysis=[];
        ReleaseFig=0;
    elseif nargin==9
        ImageArray=varargin{1};
        DataRegion=varargin{2};
        if ~isempty(DataRegion)
            DataRegionMaskOn=1;
            DataRegionBorderOn=1;
            [DataRegionBorderLine]=FindROIBorders(DataRegion,1);
        else
            DataRegionMaskOn=0;
            DataRegionBorderOn=0;
            DataRegionBorderLine=[];
        end
        StackOrder=varargin{3};
        Channel_Labels=varargin{4};
        Channel_Colors=varargin{5};
        Channel_Info=varargin{6};
        ImagingInfo=varargin{7};
        SaveName=varargin{8};
        InputAnalysis=varargin{9};
        ReleaseFig=0;
    elseif nargin==10
        ImageArray=varargin{1};
        DataRegion=varargin{2};
        if ~isempty(DataRegion)
            DataRegionMaskOn=1;
            DataRegionBorderOn=1;
            [DataRegionBorderLine]=FindROIBorders(DataRegion,1);
        else
            DataRegionMaskOn=0;
            DataRegionBorderOn=0;
            DataRegionBorderLine=[];
        end
        StackOrder=varargin{3};
        Channel_Labels=varargin{4};
        Channel_Colors=varargin{5};
        Channel_Info=varargin{6};
        ImagingInfo=varargin{7};
        SaveName=varargin{8};
        InputAnalysis=varargin{9};
        ReleaseFig=varargin{10};
    else
        error('Too Many Inputs!')
    end
    if isempty(Channel_Info)
        DefineContrastLims=1;
    else
        if isfield(Channel_Info,'Display_Limits')
            if ~isempty(Channel_Info(1).Display_Limits)
                warning('Display Limits Imported')
                DefineContrastLims=0;
            else
                DefineContrastLims=1;
            end
        else
            DefineContrastLims=1;
        end
    end
    if ~isempty(InputAnalysis)
        if isfield(InputAnalysis,'LocalizationMarkers')
            LocalizationMarkers=InputAnalysis.LocalizationMarkers;
            LocalizationMarkersOn=1;
            for l=1:length(LocalizationMarkers)
                LocalzationTypes{l}=LocalizationMarkers(l).Label;
            end
            LocalzationTypes{length(LocalizationMarkers)+1}='ADD';
            CurrentLocalizationType=1;
        else
            LocalizationMarkers=[];
            LocalizationMarkersOn=0;
            LocalzationTypes{1}='NONE';
            LocalzationTypes{2}='ADD';
            CurrentLocalizationType=1;
        end
        if isfield(InputAnalysis,'ROIs')
            ROIs=InputAnalysis.ROIs;
            if ~isempty(ROIs)
                ROITraces=1;
                ROIBorders=1;
            else
                ROITraces=0;
                ROIBorders=0;
            end
        else
            ROIs=[];
            ROITraces=0;
            ROIBorders=0;
        end
        if isfield(InputAnalysis,'EditRecord')
            EditRecord=InputAnalysis.EditRecord;
        else
            EditRecord=[];
        end
        if isfield(InputAnalysis,'Tracker_Z_Data')
            Tracker_Z_Data=InputAnalysis.Tracker_Z_Data;
        else
            Tracker_Z_Data=[];
        end
        if isfield(InputAnalysis,'Tracker_T_Data')
            Tracker_T_Data=InputAnalysis.Tracker_T_Data;
        else
            Tracker_T_Data=[];
        end
        if isfield(InputAnalysis,'Locations')
            Locations=InputAnalysis.Locations;
        else
            Locations=[];
        end
        if isfield(InputAnalysis,'ProfileInfo')
            ProfileInfo=InputAnalysis.ProfileInfo;
        else
            ProfileInfo=[];
        end
        if isfield(InputAnalysis,'FrameMarkers')
            FrameMarkers=InputAnalysis.FrameMarkers;
            if ~isempty(FrameMarkers)
                FrameMarkersOn=1;
                FrameMarkerLabelsOn=1;
            else
                FrameMarkersOn=0;
                FrameMarkerLabelsOn=0;
            end
        else
            FrameMarkers=[];
            FrameMarkersOn=0;
            FrameMarkerLabelsOn=0;
        end
        if isfield(InputAnalysis,'ProfileInfo')
            ProfileInfo=InputAnalysis.ProfileInfo;
        else
            ProfileInfo=[];
        end
        if isfield(InputAnalysis,'ExportSettings')
            ExportSettings=InputAnalysis.ExportSettings;
        else
            ExportSettings=[];
        end
        if isfield(InputAnalysis,'TileSettings')
            TileSettings=InputAnalysis.TileSettings;
        else
            TileSettings=[];
        end
        if isfield(InputAnalysis,'Z_ProjectionSettings')
            Z_ProjectionSettings=InputAnalysis.Z_ProjectionSettings;
        else
            Z_ProjectionSettings=[];
        end
        if isfield(InputAnalysis,'T_ProjectionSettings')
            T_ProjectionSettings=InputAnalysis.T_ProjectionSettings;
        else
            T_ProjectionSettings=[];
        end
        if isfield(InputAnalysis,'ScaleBar')
            ScaleBar=InputAnalysis.ScaleBar;
            if ~isempty(ScaleBar)
                ScaleBarOn=1;
            else
                ScaleBarOn=0;
            end
        else
            ScaleBar=[];
            ScaleBarOn=0;
        end
        if isfield(InputAnalysis,'ZoomScaleBar')
            ZoomScaleBar=InputAnalysis.ZoomScaleBar;
        else
            ZoomScaleBar=[];
        end
        if isfield(InputAnalysis,'ColorBarOverlay')
            ColorBarOverlay=InputAnalysis.ColorBarOverlay;
        else
            ColorBarOverlay=[];
        end
        if isfield(InputAnalysis,'MergeChannel')
            MergeChannel=InputAnalysis.MergeChannel;
            if MergeChannel
                warning('Turning Merge off to start...')
                MergeChannel=0;
            end
        else
            MergeChannel=0;
        end
        if isfield(InputAnalysis,'LiveMerge')
            LiveMerge=InputAnalysis.LiveMerge;
        else
            LiveMerge=0;
        end
        if isfield(InputAnalysis,'Channels2Merge')
            Channels2Merge=InputAnalysis.Channels2Merge;
        else
            Channels2Merge=[];
        end
        if isfield(InputAnalysis,'ImageLabel')
            ImageLabel=InputAnalysis.ImageLabel;
            if ~isempty(ImageLabel)
                ImageLabelOn=1;
            else
                ImageLabelOn=0;
            end
        else
            ImageLabel=[];
            ImageLabelOn=0;
        end
        if isfield(InputAnalysis,'ZoomImageLabel')
            ZoomImageLabel=InputAnalysis.ZoomImageLabel;
        else
            ZoomImageLabel=[];
        end

    else
        LocalizationMarkers=[];
        LocalizationMarkersOn=0;
        LocalzationTypes{1}='NONE';
        LocalzationTypes{2}='ADD';
        CurrentLocalizationType=1;
        FrameMarkers=[];
        FrameMarkersOn=0;
        FrameMarkerLabelsOn=0;
        ROIs=[];
        ROITraces=0;
        ROIBorders=0;
        EditRecord=[];
        Tracker_Z_Data=[];
        Tracker_T_Data=[];
        Locations=[];
        ProfileInfo=[];
        ExportSettings=[];
        TileSettings=[];
        Z_ProjectionSettings=[];
        T_ProjectionSettings=[];
        ScaleBar=[];
        ScaleBarOn=0;
        ZoomScaleBar=[];
        ColorBarOverlay=[];
        MergeChannel=0;
        LiveMerge=0;
        Channels2Merge=[];
        ImageLabel=[];
        ZoomImageLabel=[];
        ImageLabelOn=0;

    end
    NumOutputArgs=nargout;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Instruction Prompt
    for zzzz=1:1
        Instructions={...
        'Instructions: ';...
        '     <L/R Arrows> will navigate frames or channels';...
        '     <U/D Arrows> will navigate slices, channels, or contrast';...
        '     <PageU/PageD> will navigate channels';...
        '     <+/-> will increase or decrease contrast';...
        '     <SPACE> will Play/Pause';...
        '     <Shift> will Flag Position';...
        '     <Control> will Zoom';...
        '     <Home> will Reset Zoom';...
        '     <Insert> will Tag Position';...
        '     <Delete> will Untag Position';...
        '     <alt> will allow edits on current channel';...
        '     <x> will ADD Edit';...
        '     <z> will UNDO Edit';...
        '     <Esc/End> will ExitStackViewer';...
        '     Sometimes images linger so use <Refresh> to clear';...
        '     Manual Controls: For Manually Adjusting <FPS>, <Frame>,';...
        '                      <High^>, <Low^> Contrast Adjustments';...
        '                      Channel, Frame, or Slice Position';...
        '                      Type in the desired value within the box';...
        '                      and then click the respective button';...
        '                      to register the change';...
        '                      which should occur immediately';...
        '                      even during playback';...
        '     Zooming: Clicking Zoom will provide an ROI selection tool';...
        '              to define the Zoom area';...
        '              Select a DataRegion by connecting the dots.';...
        '              When a complete DataRegion is selected';...
        '              right click and select create mask to establish the ROI';...
        '              and when the Zoom button is pressed again it will return';...
        '              to the original un-zoomed image';...
        'More Notes:';...
        'FPS is not accurate, more of a relative guide to playback speed';...
        'Contrast Limits will be displayed on both the histogram and traces';...
        'and should update accordingly. When adding a mask the Mask limits will be';...
        'set with a dialog. Turning on masking is a bit demanding so I would not';...
        'use playback with the mask on for more than one or two frames.';...
        'Live histograms will update with each frame/slide as well. To get better ';...
        'traces you can use either the pixel trace or ROI tracing and add';...
        'as many as you want.';...
        };
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Few Starting parameters
        AutoAdjustPercents=[0.25,0.5];%[LowLim HighLim]
        AutoContrastHighScalar=0.8;
        AutoContrastLowScalar=0.5;
        TextUpdateIntervals=10;
        ColorMapOptions={'jet','parula','gray','r','g','b','c','m','y','w','hsv','hot','cool','spring','summer','autumn','winter','bone','copper','pink','lines','colorcube','prism','flag','white'};
        StackOrderOptions3={'YXT';'YXZ';'YXC'};
        StackOrderOptions4={'YXZT';'YXTZ';'YXCT';'YXTC';'YXZC';'YXCZ';'YX[RGB]T';'YXT[RGB]'};
        StackOrderOptions5={'YXTZC','YXZTC'};
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Initialization
    for zzzz=1:1
        ImageArrayDimensions=size(ImageArray);
        OverallMinVal=min(ImageArray(:));
        OverallMaxVal=max(ImageArray(:));
        Question={['Data have ',num2str(length(ImageArrayDimensions)),' Dimensions'];['(',num2str(ImageArrayDimensions),'} Dimension Order?']};
        DataClass=class(ImageArray);
        ImageArray=double(ImageArray);
        if isempty(StackOrder)
            switch length(ImageArrayDimensions)
                case 3
                    [StackOrderChoice, ~] = listdlg('PromptString',Question,'SelectionMode','single','ListString',StackOrderOptions3,'ListSize', [200 200]);
                    StackOrder=StackOrderOptions3{StackOrderChoice};
                case 4
                    [StackOrderChoice, ~] = listdlg('PromptString',Question,'SelectionMode','single','ListString',StackOrderOptions4,'ListSize', [200 200]);
                    StackOrder=StackOrderOptions4{StackOrderChoice};
                case 5
                    [StackOrderChoice, ~] = listdlg('PromptString',Question,'SelectionMode','single','ListString',StackOrderOptions5,'ListSize', [200 200]);
                    StackOrder=StackOrderOptions5{StackOrderChoice};
                    error('Not currently set up for 5D!')
            end
        end
        switch StackOrder
            case 'YXT'
                %CurrentImage=ImageArray(:,:,Frame);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                T_Stack=1;
                RGB_Stack=0;
                C_Stack=0;
                Z_Stack=0;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                Y_Dim=1;
                X_Dim=2;
                T_Dim=3;
                C_Dim=0;
                Z_Dim=0;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                ImageHeight=size(ImageArray,Y_Dim);
                ImageWidth=size(ImageArray,X_Dim);
                Last_T=size(ImageArray,T_Dim);
                Last_Z=1;
                Last_C=1;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                Channel=1;
                Slice=1;
                Channel_Info(Channel).Overall_MeanValues=[];
                fprintf('Pre-Scanning Frames');
                f = waitbar(0,['Pre-Scanning Frames...']);
                for t=1:Last_T
                    TempImage=ImageArray(:,:,t);
                    if ~isempty(DataRegion)
                        if length(size(DataRegion))>2
                            TempImage(~DataRegion(:,:,t))=NaN;
                        else
                            TempImage(~DataRegion)=NaN;
                        end
                        ImageArray(:,:,t)=TempImage;
                    end
                    Channel_Info(Channel).Overall_MeanValues(t)=nanmean(TempImage(:));
                    Channel_Info(Channel).Slice(Slice).Overall_MeanValues(t)=nanmean(TempImage(:));
                    if any(t==[1:round(Last_T/TextUpdateIntervals):Last_T])
                        fprintf('.')
                    end
                    waitbar(t/Last_T,f,['Pre-Scanning Frames...']);
                end
                fprintf('Finished!\n');
                waitbar(1,f,['Finished!']);
                close(f)
                Channel_Info(Channel).MinVal=min(ImageArray(:));
                Channel_Info(Channel).MaxVal=max(ImageArray(:));
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            case 'YXZ'
                %CurrentImage=ImageArray(:,:,Slice);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                T_Stack=0;
                RGB_Stack=0;
                C_Stack=0;
                Z_Stack=1;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                Y_Dim=1;
                X_Dim=2;
                T_Dim=0;
                C_Dim=0;
                Z_Dim=3;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                ImageHeight=size(ImageArray,Y_Dim);
                ImageWidth=size(ImageArray,X_Dim);
                Last_T=1;
                Last_Z=size(ImageArray,Z_Dim);
                Last_C=1;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                Channel=1;
                Channel_Info(Channel).Overall_MeanValues=[];
                fprintf('Pre-Scanning Slices');
                f = waitbar(0,['Pre-Scanning Slices...']);
                for z=1:Last_Z
                    TempImage=ImageArray(:,:,z);
                    if ~isempty(DataRegion)
                        if length(size(DataRegion))>2
                            TempImage(~DataRegion(:,:,z))=NaN;
                        else
                            TempImage(~DataRegion)=NaN;
                        end
                        ImageArray(:,:,z)=TempImage;
                    end
                    if any(z==[1:round(Last_Z/TextUpdateIntervals):Last_Z])
                        fprintf('.')
                    end
                    waitbar(z/Last_Z,f,['Pre-Scanning Slices...']);
                end
                fprintf('Finished!\n');
                waitbar(1,f,['Finished!']);
                close(f)
                Channel_Info(Channel).MinVal=min(ImageArray(:));
                Channel_Info(Channel).MaxVal=max(ImageArray(:));
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            case 'YXC'
                %CurrentImage=ImageArray(:,:,Channel);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                T_Stack=0;
                RGB_Stack=0;
                C_Stack=1;
                Z_Stack=0;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                Y_Dim=1;
                X_Dim=2;
                T_Dim=0;
                C_Dim=3;
                Z_Dim=0;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                ImageHeight=size(ImageArray,Y_Dim);
                ImageWidth=size(ImageArray,X_Dim);
                Last_T=1;
                Last_Z=1;
                Last_C=size(ImageArray,C_Dim);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                Slice=1;
                for c=1:Last_C
                    Channel_Info(c).Overall_MeanValues=[];
                    Channel_Info(c).MinVal=[];
                    Channel_Info(c).MaxVal=[];
                end
                fprintf('Pre-Scanning Channels');
                f = waitbar(0,['Pre-Scanning Channels...']);
                for c=1:Last_C
                    TempImage=ImageArray(:,:,c);
                    if ~isempty(DataRegion)
                        if length(size(DataRegion))>2
                            TempImage(~DataRegion(:,:,c))=NaN;
                        else
                            TempImage(~DataRegion)=NaN;
                        end
                        ImageArray(:,:,c)=TempImage;
                    end
                    Channel_Info(c).MinVal=min(min(min(ImageArray(:,:,c))));
                    Channel_Info(c).MaxVal=max(max(max(ImageArray(:,:,c))));
                    if any(c==[1:round(Last_C/TextUpdateIntervals):Last_C])
                        fprintf('.')
                    end
                    waitbar(c/Last_C,f,['Pre-Scanning Channels...']);
                end
                fprintf('Finished!\n');
                waitbar(1,f,['Finished!']);
                close(f)
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            case 'YXZT'
                %CurrentImage=ImageArray(:,:,Slice,Frame);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                T_Stack=1;
                RGB_Stack=0;
                C_Stack=0;
                Z_Stack=1;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                Y_Dim=1;
                X_Dim=2;
                T_Dim=4;
                C_Dim=0;
                Z_Dim=3;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                ImageHeight=size(ImageArray,Y_Dim);
                ImageWidth=size(ImageArray,X_Dim);
                Last_T=size(ImageArray,T_Dim);
                Last_Z=size(ImageArray,Z_Dim);
                Last_C=1;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                c=1;
                Channel_Info(c).Overall_MeanValues=[];
                Channel_Info(c).MinVal=[];
                Channel_Info(c).MaxVal=[];
                count=0;
                fprintf(['Pre-Scanning Slices and Frames']);
                f = waitbar(0,['Pre-Scanning Slices and Frames...']);
                for t=1:Last_T
                    TempStack=ImageArray(:,:,:,t);
                    TempStack=squeeze(TempStack);
                    if ~isempty(DataRegion)
                        for z=1:size(TempStack,3)
                            TempImage=TempStack(:,:,z);
                            if length(size(DataRegion))>2
                                TempImage(~DataRegion(:,:,z))=NaN;
                            else
                                TempImage(~DataRegion)=NaN;
                            end
                            TempStack(:,:,z)=TempImage;
                        end
                    end
                    Channel_Info(c).Overall_MeanValues(t)=nanmean(TempStack(:));
                    for z=1:Last_Z
                        TempImage=ImageArray(:,:,z,t);
                        if ~isempty(DataRegion)
                            if length(size(DataRegion))>2
                                TempImage(~DataRegion(:,:,z,t))=NaN;
                            else
                                TempImage(~DataRegion)=NaN;
                            end
                            ImageArray(:,:,z,t)=TempImage;
                        end
                        Channel_Info(c).Overall_MeanValues(t)=nanmean(TempImage(:));
                        Channel_Info(c).Slice(z).Overall_MeanValues(t)=nanmean(TempImage(:));
                        count=count+1;
                        if any(count==[1:round((Last_Z*Last_T)/TextUpdateIntervals):(Last_Z*Last_T)])
                            fprintf('.')
                        end
                        waitbar(count/round(Last_Z*Last_T),f,['Pre-Scanning Slices and Frames...']);
                    end
                end
                fprintf('Finished!\n');
                waitbar(1,f,['Finished!']);
                close(f)
                Channel_Info(c).MinVal=min(ImageArray(:));
                Channel_Info(c).MaxVal=max(ImageArray(:));
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            case 'YXTZ'
                %CurrentImage=ImageArray(:,:,Frame,Slice);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                T_Stack=1;
                RGB_Stack=0;
                C_Stack=0;
                Z_Stack=1;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                Y_Dim=1;
                X_Dim=2;
                T_Dim=3;
                C_Dim=0;
                Z_Dim=4;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                ImageHeight=size(ImageArray,Y_Dim);
                ImageWidth=size(ImageArray,X_Dim);
                Last_T=size(ImageArray,T_Dim);
                Last_Z=size(ImageArray,Z_Dim);
                Last_C=1;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                c=1;
                Channel_Info(c).Overall_MeanValues=[];
                Channel_Info(c).MinVal=[];
                Channel_Info(c).MaxVal=[];
                count=0;
                fprintf(['Pre-Scanning Slices and Frames']);
                f = waitbar(0,['Pre-Scanning Slices and Frames...']);
                for t=1:Last_T
                    TempStack=ImageArray(:,:,t,:);
                    TempStack=squeeze(TempStack);
                    if ~isempty(DataRegion)
                        for z=1:size(TempStack,3)
                            TempImage=TempStack(:,:,z);
                            if length(size(DataRegion))>2
                                TempImage(~DataRegion(:,:,z))=NaN;
                            else
                                TempImage(~DataRegion)=NaN;
                            end
                            TempStack(:,:,z)=TempImage;
                        end
                    end
                    Channel_Info(c).Overall_MeanValues(t)=nanmean(TempStack(:));
                    for z=1:Last_Z
                        TempImage=ImageArray(:,:,t,z);
                        if ~isempty(DataRegion)
                            if length(size(DataRegion))>2
                                TempImage(~DataRegion(:,:,t,z))=NaN;
                            else
                                TempImage(~DataRegion)=NaN;
                            end
                            ImageArray(:,:,t,z)=TempImage;
                        end
                        Channel_Info(c).Overall_MeanValues(t)=nanmean(TempImage(:));
                        Channel_Info(c).Slice(z).Overall_MeanValues(t)=nanmean(TempImage(:));
                        count=count+1;
                        if any(count==[1:round((Last_Z*Last_T)/TextUpdateIntervals):(Last_Z*Last_T)])
                            fprintf('.')
                        end
                        waitbar(count/round(Last_Z*Last_T),f,['Pre-Scanning Slices and Frames...']);
                    end
                end
                fprintf('Finished!\n');
                waitbar(1,f,['Finished!']);
                close(f)
                Channel_Info(c).MinVal=min(ImageArray(:));
                Channel_Info(c).MaxVal=max(ImageArray(:));
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            case 'YXTC'
                %CurrentImage=ImageArray(:,:,Frame,Channel);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                T_Stack=1;
                RGB_Stack=0;
                C_Stack=1;
                Z_Stack=0;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                Y_Dim=1;
                X_Dim=2;
                T_Dim=3;
                C_Dim=4;
                Z_Dim=0;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                ImageHeight=size(ImageArray,Y_Dim);
                ImageWidth=size(ImageArray,X_Dim);
                Last_T=size(ImageArray,T_Dim);
                Last_Z=1;
                Last_C=size(ImageArray,C_Dim);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                Slice=1;
                for c=1:Last_C
                    Channel_Info(c).Overall_MeanValues=[];
                    Channel_Info(c).MinVal=[];
                    Channel_Info(c).MaxVal=[];
                end
                for c=1:Last_C
                    fprintf(['Pre-Scanning ','Channel ',num2str(c),' and Frames']);
                    f = waitbar(0,['Pre-Scanning ','Channel ',num2str(c),' and Frames...']);
                    for t=1:Last_T
                        TempImage=ImageArray(:,:,t,c);
                        if ~isempty(DataRegion)
                            if length(size(DataRegion))>2
                                TempImage(~DataRegion(:,:,t,c))=NaN;
                            else
                                TempImage(~DataRegion)=NaN;
                            end
                            ImageArray(:,:,t,c)=TempImage;
                        end
                        Channel_Info(c).Overall_MeanValues(t)=nanmean(TempImage(:));
                        Channel_Info(c).Slice(Slice).Overall_MeanValues(t)=nanmean(TempImage(:));
                        if any(t==[1:round(Last_T/TextUpdateIntervals):Last_T])
                            fprintf('.')
                        end
                        waitbar(t/Last_T,f,['Pre-Scanning ','Channel ',num2str(c),' and Frames...']);
                    end
                    Channel_Info(c).MinVal=min(min(min(ImageArray(:,:,:,c))));
                    Channel_Info(c).MaxVal=max(max(max(ImageArray(:,:,:,c))));
                    fprintf('Finished!\n');
                    waitbar(1,f,['Finished!']);
                    close(f)
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            case 'YXCT'
                %CurrentImage=ImageArray(:,:,Channel,Frame);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                T_Stack=1;
                RGB_Stack=0;
                C_Stack=1;
                Z_Stack=0;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                Y_Dim=1;
                X_Dim=2;
                T_Dim=4;
                C_Dim=3;
                Z_Dim=0;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                ImageHeight=size(ImageArray,Y_Dim);
                ImageWidth=size(ImageArray,X_Dim);
                Last_T=size(ImageArray,T_Dim);
                Last_Z=1;
                Last_C=size(ImageArray,C_Dim);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                Slice=1;
                for c=1:Last_C
                    Channel_Info(c).Overall_MeanValues=[];
                    Channel_Info(c).MinVal=[];
                    Channel_Info(c).MaxVal=[];
                end
                for c=1:Last_C
                    fprintf(['Pre-Scanning ','Channel ',num2str(c),' and Frames']);
                    f = waitbar(0,['Pre-Scanning ','Channel ',num2str(c),' and Frames...']);
                    for t=1:Last_T
                        TempImage=ImageArray(:,:,c,t);
                        if ~isempty(DataRegion)
                            if length(size(DataRegion))>2
                                TempImage(~DataRegion(:,:,c,t))=NaN;
                            else
                                TempImage(~DataRegion)=NaN;
                            end
                            ImageArray(:,:,c,t)=TempImage;
                        end
                        Channel_Info(c).Overall_MeanValues(t)=nanmean(TempImage(:));
                        Channel_Info(c).Slice(Slice).Overall_MeanValues(t)=nanmean(TempImage(:));
                        if any(t==[1:round(Last_T/TextUpdateIntervals):Last_T])
                            fprintf('.')
                        end
                        waitbar(t/Last_T,f,['Pre-Scanning ','Channel ',num2str(c),' and Frames...']);
                    end
                    Channel_Info(c).MinVal=min(min(min(ImageArray(:,:,c,:))));
                    Channel_Info(c).MaxVal=max(max(max(ImageArray(:,:,c,:))));
                    fprintf('Finished!\n');
                    waitbar(1,f,['Finished!']);
                    close(f)
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            case 'YXZC'
                %CurrentImage=ImageArray(:,:,Slice,Frame);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                T_Stack=0;
                RGB_Stack=0;
                C_Stack=1;
                Z_Stack=1;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                Y_Dim=1;
                X_Dim=2;
                T_Dim=0;
                C_Dim=4;
                Z_Dim=3;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                ImageHeight=size(ImageArray,Y_Dim);
                ImageWidth=size(ImageArray,X_Dim);
                Last_T=1;
                Last_Z=size(ImageArray,Z_Dim);
                Last_C=size(ImageArray,C_Dim);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                for c=1:Last_C
                    Channel_Info(c).Overall_MeanValues=[];
                    Channel_Info(c).MinVal=[];
                    Channel_Info(c).MaxVal=[];
                end
                for c=1:Last_C
                    fprintf(['Pre-Scanning ','Channel ',num2str(c),' and Slices']);
                    f = waitbar(0,['Pre-Scanning ','Channel ',num2str(c),' and Slices...']);
                    for z=1:Last_Z
                        TempImage=ImageArray(:,:,z,c);
                        if length(size(DataRegion))>2
                            TempImage(~DataRegion(:,:,z,c))=NaN;
                        else
                            TempImage(~DataRegion)=NaN;
                        end
                        ImageArray(:,:,z,c)=TempImage;
                        Channel_Info(c).Overall_MeanValues(z)=nanmean(TempImage(:));
                        Channel_Info(c).Slice(z).Overall_MeanValues=nanmean(TempImage(:));
                        if any(z==[1:round(Last_Z/TextUpdateIntervals):Last_Z])
                            fprintf('.')
                        end
                        waitbar(z/Last_Z,f,['Pre-Scanning ','Channel ',num2str(c),' and Slices...']);
                    end
                    Channel_Info(c).MinVal=min(min(min(ImageArray(:,:,:,c))));
                    Channel_Info(c).MaxVal=max(max(max(ImageArray(:,:,:,c))));
                    fprintf('Finished!\n');
                    waitbar(1,f,['Finished!']);
                    close(f)
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            case 'YXCZ'
                %CurrentImage=ImageArray(:,:,Slice,Frame);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                T_Stack=0;
                RGB_Stack=0;
                C_Stack=1;
                Z_Stack=1;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                Y_Dim=1;
                X_Dim=2;
                T_Dim=0;
                C_Dim=3;
                Z_Dim=4;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                ImageHeight=size(ImageArray,Y_Dim);
                ImageWidth=size(ImageArray,X_Dim);
                Last_T=1;
                Last_Z=size(ImageArray,Z_Dim);
                Last_C=size(ImageArray,C_Dim);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                for c=1:Last_C
                    Channel_Info(c).Overall_MeanValues=[];
                    Channel_Info(c).MinVal=[];
                    Channel_Info(c).MaxVal=[];
                end
                for c=1:Last_C
                    fprintf(['Pre-Scanning ','Channel ',num2str(c),' and Slices']);
                    f = waitbar(0,['Pre-Scanning ','Channel ',num2str(c),' and Slices...']);
                    for z=1:Last_Z
                        TempImage=ImageArray(:,:,c,z);
                        if length(size(DataRegion))>2
                            TempImage(~DataRegion(:,:,c,z))=NaN;
                        else
                            TempImage(~DataRegion)=NaN;
                        end
                        ImageArray(:,:,c,z)=TempImage;
                        Channel_Info(c).Overall_MeanValues(z)=nanmean(TempImage(:));
                        Channel_Info(c).Slice(z).Overall_MeanValues=nanmean(TempImage(:));
                        if any(z==[1:round(Last_Z/TextUpdateIntervals):Last_Z])
                            fprintf('.')
                        end
                        waitbar(z/Last_Z,f,['Pre-Scanning ','Channel ',num2str(c),' and Slices...']);
                    end
                    Channel_Info(c).MinVal=min(min(min(ImageArray(:,:,c,:))));
                    Channel_Info(c).MaxVal=max(max(max(ImageArray(:,:,c,:))));
                    fprintf('Finished!\n');
                    waitbar(1,f,['Finished!']);
                    close(f)
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            case 'YXZTC'
                %CurrentImage=ImageArray(:,:,Slice,Frame);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                T_Stack=1;
                RGB_Stack=0;
                C_Stack=1;
                Z_Stack=1;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                Y_Dim=1;
                X_Dim=2;
                T_Dim=4;
                C_Dim=5;
                Z_Dim=3;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                ImageHeight=size(ImageArray,Y_Dim);
                ImageWidth=size(ImageArray,X_Dim);
                Last_T=size(ImageArray,T_Dim);
                Last_Z=size(ImageArray,Z_Dim);
                Last_C=size(ImageArray,C_Dim);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                for c=1:Last_C
                    Channel_Info(c).Overall_MeanValues=[];
                    Channel_Info(c).MinVal=[];
                    Channel_Info(c).MaxVal=[];
                    count=0;
                    fprintf(['Pre-Scanning ','Channel ',num2str(c),' Slices and Frames']);
                    f = waitbar(0,['Pre-Scanning ','Channel ',num2str(c),' Slices and Frames...']);
                    for t=1:Last_T
                        TempStack=ImageArray(:,:,:,t,c);
                        TempStack=squeeze(TempStack);
                        if ~isempty(DataRegion)
                            for z=1:size(TempStack,3)
                                TempImage=TempStack(:,:,z);
                                if length(size(DataRegion))>2
                                    TempImage(~DataRegion(:,:,z))=NaN;
                                else
                                    TempImage(~DataRegion)=NaN;
                                end
                                TempStack(:,:,z)=TempImage;
                            end
                        end
                        Channel_Info(c).Overall_MeanValues(t)=nanmean(TempStack(:));
                        for z=1:Last_Z
                            TempImage=ImageArray(:,:,z,t,c);
                            if ~isempty(DataRegion)
                                if length(size(DataRegion))>2
                                    TempImage(~DataRegion(:,:,z,t,c))=NaN;
                                else
                                    TempImage(~DataRegion)=NaN;
                                end
                                ImageArray(:,:,z,t,c)=TempImage;
                            end
                            Channel_Info(c).Slice(z).Overall_MeanValues(t)=nanmean(TempImage(:));
                            count=count+1;
                            if any(count==[1:round((Last_Z*Last_T)/TextUpdateIntervals):(Last_Z*Last_T)])
                                fprintf('.')
                            end
                            waitbar(count/round(Last_Z*Last_T),f,['Pre-Scanning ','Channel ',num2str(c),' Slices and Frames...']);
                        end
                    end
                    fprintf('Finished!\n');
                    waitbar(1,f,['Finished!']);
                    close(f)
                    Channel_Info(c).MinVal=min(min(min(min(ImageArray(:,:,:,:,c)))));
                    Channel_Info(c).MaxVal=max(max(max(max(ImageArray(:,:,:,:,c)))));
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            case 'YXTZC'
                %CurrentImage=ImageArray(:,:,Frame,Slice);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                T_Stack=1;
                RGB_Stack=0;
                C_Stack=1;
                Z_Stack=1;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                Y_Dim=1;
                X_Dim=2;
                T_Dim=3;
                C_Dim=5;
                Z_Dim=4;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                ImageHeight=size(ImageArray,Y_Dim);
                ImageWidth=size(ImageArray,X_Dim);
                Last_T=size(ImageArray,T_Dim);
                Last_Z=size(ImageArray,Z_Dim);
                Last_C=size(ImageArray,C_Dim);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                for c=1:Last_C
                    Channel_Info(c).Overall_MeanValues=[];
                    Channel_Info(c).MinVal=[];
                    Channel_Info(c).MaxVal=[];
                    count=0;
                    fprintf(['Pre-Scanning ','Channel ',num2str(c),' Slices and Frames']);
                    f = waitbar(0,['Pre-Scanning ','Channel ',num2str(c),' Slices and Frames...']);
                    for t=1:Last_T
                        TempStack=ImageArray(:,:,t,:,c);
                        TempStack=squeeze(TempStack);
                        if ~isempty(DataRegion)
                            for z=1:size(TempStack,3)
                                TempImage=TempStack(:,:,z);
                                if length(size(DataRegion))>2
                                    TempImage(~DataRegion(:,:,z))=NaN;
                                else
                                    TempImage(~DataRegion)=NaN;
                                end
                                TempStack(:,:,z)=TempImage;
                            end
                        end
                        Channel_Info(c).Overall_MeanValues(t)=nanmean(TempStack(:));
                        for z=1:Last_Z
                            TempImage=ImageArray(:,:,t,z,c);
                            if ~isempty(DataRegion)
                                if length(size(DataRegion))>2
                                    TempImage(~DataRegion(:,:,t,z,c))=NaN;
                                else
                                    TempImage(~DataRegion)=NaN;
                                end
                                ImageArray(:,:,t,z,c)=TempImage;
                            end
                            Channel_Info(c).Overall_MeanValues(t)=nanmean(TempImage(:));
                            Channel_Info(c).Slice(z).Overall_MeanValues(t)=nanmean(TempImage(:));
                            count=count+1;
                            if any(count==[1:round((Last_Z*Last_T)/TextUpdateIntervals):(Last_Z*Last_T)])
                                fprintf('.')
                            end
                            waitbar(count/round(Last_Z*Last_T),f,['Pre-Scanning ','Channel ',num2str(c),' Slices and Frames...']);
                        end
                    end
                    fprintf('Finished!\n');
                    waitbar(1,f,['Finished!']);
                    close(f)
                    Channel_Info(c).MinVal=min(min(min(min(ImageArray(:,:,:,:,c)))));
                    Channel_Info(c).MaxVal=max(max(max(max(ImageArray(:,:,:,:,c)))));
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            case 'YX[RGB]T'
                %CurrentImage=ImageArray(:,:,:,Frame);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                T_Stack=1;
                RGB_Stack=1;
                C_Stack=0;
                Z_Stack=0;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                Y_Dim=1;
                X_Dim=2;
                T_Dim=4;
                C_Dim=0;
                Z_Dim=0;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                ImageHeight=size(ImageArray,Y_Dim);
                ImageWidth=size(ImageArray,X_Dim);
                Last_T=size(ImageArray,T_Dim);
                Last_Z=1;
                Last_C=1;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                Slice=1;
                Channel=1;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            case 'YXT[RGB]'
                %CurrentImage=ImageArray(:,:,Frame,:);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                T_Stack=1;
                RGB_Stack=1;
                C_Stack=0;
                Z_Stack=0;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                Y_Dim=1;
                X_Dim=2;
                T_Dim=3;
                C_Dim=0;
                Z_Dim=0;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                ImageHeight=size(ImageArray,Y_Dim);
                ImageWidth=size(ImageArray,X_Dim);
                Last_T=size(ImageArray,T_Dim);
                Last_Z=1;
                Last_C=size(ImageArray,C_Dim);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                Slice=1;
                Channel=1;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if ~isempty(DataRegion)
            if length(size(DataRegion))>2
                if any(size(DataRegion)~=size(ImageArray))
                    error('If you supply a DataRegion Stack it must be the same size as the input ImageArray')
                else
                    TotalImagePixelCount=sum(~isnan(DataRegion(:)));
                    if length(size(DataRegion))==3
                        TestRegion=max(DataRegion,[],3);
                    elseif length(size(DataRegion))==4
                        TestRegion=max(max(DataRegion,[],4),[],3);
                    elseif length(size(DataRegion))==5
                        TestRegion=max(max(max(DataRegion,[],5),[],4),[],3);
                    end
                    TotalImagePixelCount=sum(~isnan(TestRegion(:)));
                end
            else
                TotalImagePixelCount=sum(~isnan(DataRegion(:)));
            end
        else     
            TotalImagePixelCount=ImageHeight*ImageWidth;
        end
        MinNormImagePixelCount=1/TotalImagePixelCount;
        TotalPixelCount=ImageHeight*ImageWidth;
        if Last_T~=0
            TotalPixelCount=TotalPixelCount*Last_T;
        end
        if Last_Z~=0
            TotalPixelCount=TotalPixelCount*Last_Z;
        end
        MinNormTotalPixelCount=1/TotalPixelCount;
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if isempty(Channel_Labels)
            for cc=1:Last_C
                Channel_Labels{cc}=['Channel ',num2str(cc)];
            end
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        for cc=1:Last_C
            if ~RGB_Stack
                Channel_Info(cc).ValDiff=abs(Channel_Info(cc).MaxVal-Channel_Info(cc).MinVal);
                if Channel_Info(cc).ValDiff>5000
                    Channel_Info(cc).ColorScalar=0.1;
                    Channel_Info(cc).StepUnits=[100,500];
                    Channel_Info(cc).MaskLim=1000;
                elseif Channel_Info(cc).ValDiff>1000
                    Channel_Info(cc).ColorScalar=0.5;
                    Channel_Info(cc).StepUnits=[10,100];
                    Channel_Info(cc).MaskLim=10;
                elseif Channel_Info(cc).ValDiff>100
                    Channel_Info(cc).ColorScalar=1;
                    Channel_Info(cc).StepUnits=[1,10];
                    Channel_Info(cc).MaskLim=5;
                elseif Channel_Info(cc).ValDiff>10
                    Channel_Info(cc).ColorScalar=10;
                    Channel_Info(cc).StepUnits=[0.1,1];
                    Channel_Info(cc).MaskLim=1;
                elseif Channel_Info(cc).ValDiff>5
                    Channel_Info(cc).ColorScalar=20;
                    Channel_Info(cc).StepUnits=[0.05,0.5];
                    Channel_Info(cc).MaskLim=0.2;
                elseif Channel_Info(cc).ValDiff>1
                    Channel_Info(cc).ColorScalar=100;
                    Channel_Info(cc).StepUnits=[0.01,0.1];
                    Channel_Info(cc).MaskLim=0.1;
                else
                    Channel_Info(cc).ColorScalar=100;
                    Channel_Info(cc).StepUnits=[0.005,0.05];
                    Channel_Info(cc).MaskLim=0.05;
                end
                Channel_Info(cc).ValDiffRound=ceil(Channel_Info(cc).ValDiff/...
                    Channel_Info(cc).StepUnits(2))*Channel_Info(cc).StepUnits(2);
                Channel_Info(cc).DataRange=...
                    [floor(Channel_Info(cc).MinVal/...
                    Channel_Info(cc).StepUnits(2))*Channel_Info(cc).StepUnits(2),...
                    ceil(Channel_Info(cc).MaxVal/...
                    Channel_Info(cc).StepUnits(2))*Channel_Info(cc).StepUnits(2)];
                Channel_Info(cc).DisplayMinVal=Channel_Info(cc).DataRange(1)-Channel_Info(cc).ValDiffRound*AutoAdjustPercents(1);
                Channel_Info(cc).DisplayMaxVal=Channel_Info(cc).DataRange(2)+Channel_Info(cc).ValDiffRound*AutoAdjustPercents(2);
                Channel_Info(cc).DisplayValDiff=Channel_Info(cc).DisplayMaxVal-Channel_Info(cc).DisplayMinVal;
                Channel_Info(cc).DataRange=[Channel_Info(cc).DisplayMinVal,Channel_Info(cc).DisplayMaxVal];
            else
                Channel_Info(cc).MaxVal=1;
                Channel_Info(cc).MinVal=0;
                Channel_Info(cc).ValDiff=1;
                Channel_Info(cc).ColorScalar=100;
                Channel_Info(cc).StepUnits=[0.005,0.05];
                Channel_Info(cc).MaskLim=0.05;
                Channel_Info(cc).DataRange=...
                    [floor(Channel_Info(cc).MinVal/...
                    Channel_Info(cc).StepUnits(2))*Channel_Info(cc).StepUnits(2),...
                    ceil(Channel_Info(cc).MaxVal/...
                    Channel_Info(cc).StepUnits(2))*Channel_Info(cc).StepUnits(2)];
                
            end
            Channel_Info(cc).MaskOn=0;
            Channel_Info(cc).MaskAlpha=0.5;
            Channel_Info(cc).MaskColor='w';
            Channel_Info(cc).MaskInvert=0;
            Channel_Info(cc).MaskColorMap=vertcat(ColorDefinitionsLookup(Channel_Info(cc).MaskColor),[0,0,0]);
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            for cc=1:Last_C
                if isempty(Channel_Colors)
                    Channel_Info(cc).DisplayColorMapIndex=1;
                    Channel_Info(cc).DisplayColorMap=ColorMapOptions{Channel_Info(cc).DisplayColorMapIndex};
                    Channel_Info(cc).DisplayColorMapCode=ColorDefinitionsLookup(Channel_Info(cc).DisplayColorMap);
                else
                    if ischar(Channel_Colors{cc})
                        Channel_Info(cc).DisplayColorMap=Channel_Colors{cc};
                        Channel_Info(cc).DisplayColorMapCode=ColorDefinitionsLookup(Channel_Colors{cc});
                    else
                        Channel_Info(cc).DisplayColorMap=ColorAbbreviationLookup(Channel_Colors{cc});
                        Channel_Info(cc).DisplayColorMapCode=Channel_Colors{cc};
                    end
                    Channel_Info(cc).DisplayColorMapIndex=0;
                    for ccc=1:length(ColorMapOptions)
                        if ischar(Channel_Info(cc).DisplayColorMap)
                            if strcmp(Channel_Info(cc).DisplayColorMap,ColorMapOptions{ccc})
                                Channel_Info(cc).DisplayColorMapIndex=ccc;
                            end
                        else

                        end
                    end
                    if Channel_Info(cc).DisplayColorMapIndex==0
                        error('Problem finding input Colormap')
                    end
                end
                if DefineContrastLims
                    if OverallMinVal>=0
                        Channel_Info(cc).Display_Limits=[0,Channel_Info(cc).MaxVal*AutoContrastHighScalar];
                    else
                        LowAdjust=Channel_Info(cc).MinVal*AutoContrastLowScalar;
                        if Channel_Info(cc).MinVal+LowAdjust<0
                            Channel_Info(cc).Display_Limits=[Channel_Info(cc).MinVal+LowAdjust,Channel_Info(cc).MaxVal*AutoContrastHighScalar];
                        else
                            Channel_Info(cc).Display_Limits=[0,Channel_Info(cc).MaxVal*AutoContrastHighScalar];
                        end
                    end
                end
                Channel_Info(cc).Normalized_Display_Limits=...
                    (Channel_Info(cc).Display_Limits-...
                    Channel_Info(cc).DisplayMinVal)/Channel_Info(cc).DisplayValDiff;
        %         [   Channel_Info(cc).ColorMap,...
        %             Channel_Info(cc).ValueAdjust,...
        %             Channel_Info(cc).ContrastHigh,...
        %             Channel_Info(cc).ContrastLow]=...
        %             StackViewer_UniversalColorMap(Channel_Info(cc).DisplayColorMap,Channel_Info(cc).DisplayColorMapCode,...
        %                 Channel_Info(cc).Display_Limits,Channel_Info(cc).ColorScalar);
                Channel_Info(cc).Normalized_StepUnits=(Channel_Info(cc).StepUnits)/Channel_Info(cc).DisplayValDiff;
                Channel_Info(cc).ContrastOptions=[Channel_Info(cc).DisplayMinVal,Channel_Info(cc).DisplayMaxVal];
        %         if strcmp(DataClass,'double')||strcmp(DataClass,'single')
        %             Channel_Info(cc).ContrastOptions=[Channel_Info(cc).DisplayMinVal,Channel_Info(cc).DisplayMaxVal];
        %         elseif strcmp(DataClass,'uint64')||strcmp(DataClass,'int64')
        %             Channel_Info(cc).ContrastOptions=[0,2^64-1];
        %         elseif strcmp(DataClass,'uint32')||strcmp(DataClass,'int32')
        %             Channel_Info(cc).ContrastOptions=[0,2^32-1];
        %         elseif strcmp(DataClass,'uint16')||strcmp(DataClass,'int16')
        %             Channel_Info(cc).ContrastOptions=[0,2^16-1];
        %         elseif strcmp(DataClass,'uint8')||strcmp(DataClass,'int8')
        %             Channel_Info(cc).ContrastOptions=[0,2^8-1];
        %         elseif strcmp(DataClass,'logical')
        %             Channel_Info(cc).ContrastOptions=[0,1];
        %         else
        %             error('Unknown File Type')
        %         end
                if Channel_Info(cc).Display_Limits(1)==Channel_Info(cc).Display_Limits(2)
                    Channel_Info(cc).Display_Limits(2)=Channel_Info(cc).Display_Limits(1)+1;
                end
                [   Channel_Info(cc).ColorMap,...
                    Channel_Info(cc).ValueAdjust,...
                    Channel_Info(cc).ContrastHigh,...
                    Channel_Info(cc).ContrastLow]=...
                    StackViewer_UniversalColorMap(Channel_Info(cc).DisplayColorMap,Channel_Info(cc).DisplayColorMapCode,...
                        Channel_Info(cc).Display_Limits,Channel_Info(cc).ColorScalar);
            end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %Histograms
        for cc=1:Last_C
             [~,~,~,Channel_Info(cc).All_Pixels_Bin_Centers,Channel_Info(cc).All_Pixels_Hist,Channel_Info(cc).All_Pixels_Hist_Norm,...
                ~,~]=ImageHistograms(ImageArray(:),Channel_Info(cc).DataRange,Channel_Info(cc).StepUnits(2));
            for zz=1:Last_Z
                TempStack=[];
                switch StackOrder
                    case 'YXT'
                    case 'YXZ'
                        TempStack=squeeze(ImageArray(:,:,zz));
                    case 'YXC'
                    case 'YXZT'
                        TempStack=squeeze(ImageArray(:,:,zz,:));
                    case 'YXTZ'
                        TempStack=squeeze(ImageArray(:,:,:,zz));
                    case 'YXTC'
                    case 'YXCT'
                    case 'YXZC'
                        TempStack=squeeze(ImageArray(:,:,zz,:));
                    case 'YXCZ'
                        TempStack=squeeze(ImageArray(:,:,:,zz));
                    case 'YXZTC'
                        TempStack=squeeze(ImageArray(:,:,zz,:,:));
                    case 'YXTZC'
                        TempStack=squeeze(ImageArray(:,:,:,zz,:));
                    case 'YX[RGB]T'
                    case 'YXT[RGB]'
                end
                if ~isempty(TempStack)
                    [~,~,~,Channel_Info(cc).SliceInfo(zz).All_Pixels_Bin_Centers,Channel_Info(cc).SliceInfo(zz).All_Pixels_Hist,Channel_Info(cc).SliceInfo(zz).All_Pixels_Hist_Norm,...
                        ~,~]=ImageHistograms(TempStack(:),Channel_Info(cc).DataRange,Channel_Info(cc).StepUnits(2));
                else
                    Channel_Info(cc).SliceInfo(zz).All_Pixels_Bin_Centers=[];
                    Channel_Info(cc).SliceInfo(zz).All_Pixels_Hist=[];
                    Channel_Info(cc).SliceInfo(zz).All_Pixels_Hist_Norm=[];
                end
                clear TempStack
            end
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if ~isfield(Channel_Info,'Editable')
            for cc=1:Last_C
                Channel_Info(cc).Editable=0;
%                 Channel_Info(cc).IsEditRecord=0;
%                 Channel_Info(cc).EditRecordChannel=0;
            end
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Fig and Panel Position/Sizes
        if ScreenSize(3)>1200
            ViewerFigPosition=[0 50 1500 ScreenSize(4)-140];
        else
            ViewerFigPosition=[0 50 ScreenSize(3)-100 ScreenSize(4)-140];
        end
        if ViewerFigPosition(4)>ScreenSize(4)-100
            ViewerFigPositionScalarModifier=(ScreenSize(4)-100)/ViewerFigPosition(4);
            warning(['Adjusting Vertical Size by ',num2str(ViewerFigPositionScalarModifier),' to fit Monitor!'])
            ViewerFigPosition(4)=round(ViewerFigPosition(4)*ViewerFigPositionScalarModifier);
        end
        if ViewerFigPosition(3)>ScreenSize(3)-200
            ViewerFigPositionScalarModifier=(ScreenSize(3)-200)/ViewerFigPosition(3);
            warning(['Adjusting Horizontal Size by ',num2str(ViewerFigPositionScalarModifier),' to fit Monitor!'])
            ViewerFigPosition(3)=round(ViewerFigPosition(3)*ViewerFigPositionScalarModifier);
        end
        PromptViewerFigPosition=[ViewerFigPosition(1)+ViewerFigPosition(3),ViewerFigPosition(2)+ViewerFigPosition(4)-ViewerFigPosition(4)*0.3,140,140];
        TrackerFigPosition=[ViewerFigPosition(1)+ViewerFigPosition(3),ViewerFigPosition(2),200,ViewerFigPosition(4)];
        if ImageWidth>ImageHeight
            ViewerImageAxisPosition=[0.03 0.2 0.66 0.77];
            ViewerTileImageAxisPosition=[0.03 0.2 0.66 0.77];
        else
            ViewerImageAxisPosition=[0.03 0.2 0.75 0.77];
            ViewerTileImageAxisPosition=[0.03 0.2 0.66 0.77];
        end
        if ~T_Stack
            ViewerImageAxisPosition(2)=0.025;
            ViewerImageAxisPosition(4)=0.945;
            ViewerTileImageAxisPosition(2)=0.025;
            ViewerTileImageAxisPosition(4)=0.945;
        end
        HistAxisPosition=[0.79 0.25 0.2 0.3];
        TraceAxisPosition=[0.05 0.05 0.925 0.14];
        ColorBarPosition=[0.875 0.675 0.01 0.1];
        ColorBarAxisPosition=[0.6 0.65 0.1 0.15];
        TraceExportFigPosition=ViewerFigPosition;
        TraceExportAxesPosition=[0.15,0.15,0.8,0.8];
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %initialize figure
        ViewerFig=figure;
        OutputAnalysis=InputAnalysis;
        Frame=1;
        Slice=1;
        Channel=1;
        set(ViewerFig,'units','pixels','position',ViewerFigPosition,'name',[SaveName,' Frame ',num2str(Frame),' Slice ',num2str(Slice),'  ',Channel_Labels{Channel}]);
        set(ViewerFig, 'color', 'white');
        ViewerImageAxis=axes('position',ViewerImageAxisPosition);
        MaskAxes=[];
        TileAxes=[];
        if ~RGB_Stack
            ColorBarAxis=axes('position',ColorBarAxisPosition);
            if T_Stack
                TracePlotAxis=axes('position',TraceAxisPosition);
            end
            HistAxis=axes('position',HistAxisPosition);
        end
        PromptFig=[];
        TrackerFig=[];
        Tracker_T_Axis=[];
        Tracker_Z_Axis=[];
        BufferViewerImageAxes=[];
        BufferMaskAxes=[];
        BufferTileAxes=[];
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Parameters
    for zzzz=1:1
        ZoomMethod='Custom';
        ForceGreekCharacter=1;
        FontSizeAdjust=0;
        ExportSettings.ExportIncludeTrace=1;
        ExportSettings.ExportIncludeTraceNum=1;
        ExportIncludeTraceChoice='No';
        TraceExportFormatsChoice='Both';
        TraceExportStyleChoice='Overlay';
        Printing_px2cm_scalar=0.025;
        ROI_Marker_Radius_px=round(mean([ImageHeight,ImageWidth])/100);
        ROI_Border_LineWidth=0.5;
        ROI_Border_LineStyle='-';
        SplitTraceAdjust=0;
        Trace_LineStyle='-';
        Trace_LineWidth=0.5;
        MeanTrace_LineStyle='-';
        MeanTrace_LineWidth=1.5;
        SliceMeanTrace_LineStyle=':';
        SliceMeanTrace_LineWidth=2;
        
        Thresh_LineStyle='--';
        Thresh_LineWidth=1.5;
        ThreshLow_LineColor='b';
        ThreshHigh_LineColor='g';
        ThreshMask_LineColor='r';
        
        Frame_LineStyle='--';
        Frame_LineWidth=1.5;
        Frame_LineColor='k';
       
        EditWarning=0;
        DisplayEditsOn=0;
        EditsBorderColor='r';
        EditsBorderLineStyle=':';
        EditsBorderWidth=1.5;

        AutoContrastOn=0;
        TileChannels=0;
        TileSlices=0;
        TileFrames=0;
        if isempty(TileSettings)
            TileSettings.C_Range=[];
            TileSettings.Z_Range=[];
            TileSettings.T_Range=[];
        end
        PlayBack=0;
        FPS=20;
        ZoomOn=0;
        ZoomDataRegion_Props.BoundingBox=[1,1,ImageWidth,ImageHeight];
        TraceScaleOn=0;
        TraceScaleBars=[];
        CurrentFrameMarkerOn=1;
        TraceThreshMarkersOn=1;
        %ScaleBarOn=0;
        %ScaleBar=[];
        %ZoomScaleBar=[];
        %ImageLabelOn=0;
        %ImageLabel=[];
        %ZoomImageLabel=[];
        LogHistX=0;
        LogHistY=1;
        NormHist=1;
        AutoScaleHist=0;
        if C_Stack
            LiveHist=1;
            OverallHist=0;
        else
            LiveHist=0;
            OverallHist=1;
        end
        SliceColorOn=0;
        ColorBarOverlayOn=0;
        %ColorBarOverlay=[];
        if Z_Stack
            SliceHist=1;
        else
            SliceHist=0;
        end
        DataRegionMaskColor=[0.3,0.3,0.3];
        BorderColor='w';
        BorderLineStyle='-';
        BorderWidth=1.5;
        MaskOn=0;
        Z_ProjectionOptions={'Max','Min','Avg','Sum'};
        %Z_ProjectionColoringOptions={'Channel','Unique','Graded'};
        Z_Projection=0;
        %Z_ProjectionSettings=[];
        global Z_Projection_Data
        Z_Projection_Data=[];
        global Z_Projection_Merge_Data
        Z_Projection_Merge_Data=[];
        Z_Projection_ContrastAdjusted=0;
        T_ProjectionOptions={'Max','Min','Avg','Sum'};
        %T_ProjectionColoringOptions={'Channel','Graded'};
        T_Projection=0;
        %T_ProjectionSettings=[];
        if isempty(Z_ProjectionSettings)
            Z_ProjectionSettings.Z_ProjectionType=[];
        end
        global T_Projection_Data
        %T_Projection_Data=[];
        if isempty(Z_ProjectionSettings)
            T_ProjectionSettings.T_ProjectionType=[];
        end
        global T_Projection_Merge_Data
        T_Projection_Merge_Data=[];
        T_Projection_ContrastAdjusted=0;
        ProfileOn=0;
        %ProfileInfo=[];
        %MergeChannel=0;
        %LiveMerge=0;
        %Channels2Merge=[];
        global MergeStack
        MergeStack=[];
        Merge_ContrastAdjusted=0;
        if isempty(SaveName)
            ExportSettings.MovieName=[StackOrder,' ','Movie'];
            ExportSettings.ImageName=[StackOrder,' ','Image'];
            ExportSettings.TraceExportName=[StackOrder,' ','Traces'];
            ExportSettings.DataExportName=[StackOrder,' ','Data'];
        else
            ExportSettings.MovieName=[SaveName,' ','Movie'];
            ExportSettings.ImageName=[SaveName,' ','Image'];
            ExportSettings.TraceExportName=[SaveName,' ','Traces'];
            ExportSettings.DataExportName=[SaveName,' ','Data'];
        end
        if ~isfield(ExportSettings,'MovieSpeed')
            ExportSettings.MovieSpeed=10;
            ExportSettings.MovieQuality=95;
            ExportSettings.ScaleFactor=2;
            ExportSettings.MovieRepeats=1;
            ExportSettings.MovieFrames=1;
        end
        if ~isfield(ExportSettings,'ExportLabelPos_X')
            ExportSettings.ExportLabelPos_X=0.05*ImageWidth;
            ExportSettings.ExportLabelPos_Y=0.1*ImageHeight;
            ExportSettings.ExportLabelFontSize=10;
        end
        %HighLightLineStyle='-';
        %HighLightLineColor='m';
        %HighLightLineWidth=2;
        CurrentTraceXData=[1:Last_T];
        ThreshMask=[];
        %MaskColorMap=[];
        CurrentFrameMarker=[];
        AllFrameMarkers=[];
        AllFrameMarkerLabels=[];
        TraceLow=[];
        TraceHigh=[];
        TraceMask=[];
        HistLow=[];
        HistHigh=[];
        HistMask=[];
        LiveHistTrace=[];
        AllPixelHist=[];
        %ROIs=[];
        NumROIs=0;
        MeanTraces=1;
        SliceMeanTraces=0;
        CurrentDataRegionMaskStatus=0;
        CurrentMergeChannelStatus=0;
        %Locations=[];
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
    [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
    if ~RGB_Stack
        ColorBarDisplay(ViewerFig,ColorBarAxis,ColorBarAxisPosition)
        HistDisplay(HistAxis,HistAxisPosition)
        if T_Stack
            TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
        end
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if isempty(Tracker_T_Data)
        Tracker_T_Data=zeros(Last_T,5,'logical');
    end
    if isempty(Tracker_Z_Data)
        Tracker_Z_Data=zeros(Last_Z,5,'logical');
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Create UI elements
    for zzzz=1:1
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            ExitButton = uicontrol('Style', 'pushbutton', 'String', 'Exit',...
                'units','normalized',...
                'Position', [0.97 0.97 0.03 0.03],...
                'Callback', @ExitStackViewer);
            RefreshButton = uicontrol('Style', 'pushbutton', 'String', 'Refresh',...
                'units','normalized',...
                'Position', [0.935 0.97 0.035 0.03],...
                'Callback', @RefreshViewer);
            ReleaseFigureButton = uicontrol('Style', 'pushbutton', 'String', 'Release',...
                'units','normalized',...
                'Position', [0.9 0.97 0.035 0.03],...
                'Callback', @ReleaseFigure);
            InstructButton = uicontrol('Style', 'pushbutton', 'String', 'Instructions',...
                'units','normalized',...
                'Position', [0.80 0.97 0.05 0.03],...
                'Callback', @ViewInstructions);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
             ZoomInButton = uicontrol('Style', 'togglebutton', 'String', 'Zoom In',...
                'units','normalized',...
                'value',ZoomOn,...
                'Position', [0.76 0.97 0.04 0.03],...
                'Callback', @ZoomIn);   
             ZoomResetButton = uicontrol('Style', 'pushbutton', 'String', 'ResetZoom',...
                'units','normalized',...
                'Position', [0.76 0.94 0.04 0.03],...
                'Callback', @ZoomReset);   
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
             CropDataButton = uicontrol('Style', 'pushbutton', 'String', 'Crop',...
                'units','normalized',...
                'Position', [0.80 0.94 0.05 0.03],...
                'Callback', @CropData);   
             ReorientDataButton = uicontrol('Style', 'pushbutton', 'String', 'Reorient',...
                'units','normalized',...
                'Position', [0.80 0.91 0.05 0.03],...
                'Callback', @ReorientData);   
             RegisterDataButton = uicontrol('Style', 'pushbutton', 'String', 'Register',...
                'units','normalized',...
                'Position', [0.80 0.88 0.05 0.03],...
                'Callback', @RegisterData);   
             ImageMathButton = uicontrol('Style', 'pushbutton', 'String', 'ImageMath',...
                'units','normalized',...
                'Position', [0.80 0.85 0.05 0.03],...
                'Callback', @ImageMath);   
set(RegisterDataButton,'Enable','off');
set(ImageMathButton,'Enable','off');
set(CropDataButton,'Enable','off');
set(ReorientDataButton,'Enable','off');
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Create field for setting Frame position
            FrameButton = uicontrol('Style', 'pushbutton', 'String', 'T->',...
                'units','normalized',...
                'Position', [0.85 0.94 0.02 0.03],...
                'Callback', @Jump2Frame);
            FramePos = uicontrol('Style', 'edit', 'string',num2str(Frame),...
                'units','normalized',...
                'Position', [0.87 0.94 0.03 0.03]);     
            if ~T_Stack
                set(FrameButton,'Enable','off');
                set(FramePos,'Enable','off');
            end
            % Create field for setting Slice position
            SliceButton = uicontrol('Style', 'pushbutton', 'String', 'Z->',...
                'units','normalized',...
                'Position', [0.90 0.94 0.02 0.03],...
                'Callback', @Jump2Slice);
            SlicePos = uicontrol('Style', 'edit', 'string',num2str(Slice),...
                'units','normalized',...
                'Position', [0.92 0.94 0.03 0.03]);    
            if ~Z_Stack
                set(SliceButton,'Enable','off');
                set(SlicePos,'Enable','off');
            end
            % Create field for setting Channel position
            ChannelButton = uicontrol('Style', 'pushbutton', 'String', 'C->',...
                'units','normalized',...
                'Position', [0.95 0.94 0.02 0.03],...
                'Callback', @Jump2Channel);
            ChannelPos = uicontrol('Style', 'edit', 'string',num2str(Channel),...
                'units','normalized',...
                'Position', [0.97 0.94 0.03 0.03]);     
            if ~C_Stack
                set(ChannelButton,'Enable','off');
                set(ChannelPos,'Enable','off');
            end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
           % Create push button for playing stack
           PlayLabel='Play';
           if T_Stack
               PlayLabel='PLAY T';
           elseif Z_Stack
               PlayLabel='PLAY Z';
           else
               PlayLabel='Play Off';
           end
            PlayButton = uicontrol('Style', 'togglebutton', 'String', PlayLabel,...
                'units','normalized',...
                'hittest','off',...
                'value',0,...
                'Position', [0.85 0.91 0.05 0.03],...
                'Callback', @StartPlayStack);  
            PauseButton = uicontrol('Style', 'togglebutton', 'String', 'PAUSE',...
                'units','normalized',...
                'hittest','off',...
                'value',0,...
                'Position', [0.9 0.91 0.05 0.03],...
                'Callback', @PausePlayStack);  
           if ~T_Stack&&~Z_Stack
                set(PlayButton,'Enable','off');
                set(PauseButton,'Enable','off');
           end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Create field for setting speed
            FPS_Ctl = uicontrol('Style', 'edit', 'string',num2str(FPS),...
                'units','normalized',...
                'Position', [0.98 0.91 0.02 0.03]);      
            FPSButton = uicontrol('Style', 'pushbutton', 'String', '~FPS ->',...
                'units','normalized',...
                'Position', [0.95 0.91 0.03 0.03],...
                'Callback', @ChangeSpeed); 
           if ~T_Stack&&~Z_Stack
                set(FPS_Ctl,'Enable','off');
                set(FPSButton,'Enable','off');
           end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
             FlagFrameButton = uicontrol('Style', 'pushbutton', 'String', 'FlagFrame(sh)',...
                'units','normalized',...
                'Position', [0.95 0.88 0.05 0.03],...
                'Callback', @FlagFrame);   
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
             AddLocalizationButton = uicontrol('Style', 'pushbutton', 'String', 'AddLoc',...
                'units','normalized',...
                'Position', [0.8 0.82 0.03 0.03],...
                'Callback', @AddLocalization);   
             DeleteLocalizationButton = uicontrol('Style', 'pushbutton', 'String', 'DelLoc',...
                'units','normalized',...
                'Position', [0.83 0.82 0.03 0.03],...
                'Callback', @DeleteLocalization);   
             UndoLocalizationButton = uicontrol('Style', 'pushbutton', 'String', 'UndoLoc',...
                'units','normalized',...
                'Position', [0.86 0.82 0.04 0.03],...
                'Callback', @UndoLocalization);   
             LocalizationTypeList = uicontrol('Style', 'popup',...
                'String', LocalzationTypes,...
                'units','normalized',...
                'value',CurrentLocalizationType,...
                'Position', [0.9 0.82 0.04 0.03],...
                'Callback', @SetLocalizaitonType);    
             DisplayLocalizationButton = uicontrol('Style', 'togglebutton', 'String', 'LocOn',...
                'units','normalized',...
                'value',LocalizationMarkersOn,...
                'Position', [0.94 0.82 0.03 0.03],...
                'Callback', @ToggleLocalization);   
             FormatLocalizationMarkersButton = uicontrol('Style', 'pushbutton', 'String', 'Format',...
                'units','normalized',...
                'Position', [0.97 0.82 0.03 0.03],...
                'Callback', @FormatLocalizationMarkers);   
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            ImportDataButton = uicontrol('Style', 'pushbutton', 'String', 'Import Data',...
                'units','normalized',...
                'Position', [0.85 0.97 0.05 0.03],...
                'Callback', @ImportData);
set(ImportDataButton,'Enable','off');
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            ExportAddProfileButton = uicontrol('Style', 'pushbutton', 'String', 'ExportProfile',...
                'units','normalized',...
                'Position', [0.75 0 0.05 0.025],...
                'Callback', @ExportProfile);
            ExportTraceButton = uicontrol('Style', 'pushbutton', 'String', 'ExportTraces',...
                'units','normalized',...
                'Position', [0.8 0 0.05 0.025],...
                'Callback', @ExportTrace);
            ExportImageButton = uicontrol('Style', 'pushbutton', 'String', 'Export Image',...
                'units','normalized',...
                'Position', [0.85 0 0.05 0.025],...
                'Callback', @ExportImage);
            ExportMovieButton = uicontrol('Style', 'pushbutton', 'String', 'Export Movie',...
                'units','normalized',...
                'Position', [0.9 0 0.05 0.025],...
                'Callback', @ExportMovie);
            ExportDataButton = uicontrol('Style', 'pushbutton', 'String', 'Export Data',...
                'units','normalized',...
                'Position', [0.95 0 0.05 0.025],...
                'Callback', @ExportData);
set(ExportAddProfileButton,'Enable','off');
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            MakeChannelEditableButton = uicontrol('Style', 'togglebutton', 'String', 'EditOn',...
                'value',Channel_Info(Channel).Editable,...
                'units','normalized',...
                'Position', [0.85 0.85 0.03 0.03],...
                'Callback', @MakeChannelEditable);
            EditDataButton = uicontrol('Style', 'pushbutton', 'String', 'EditC',...
                'units','normalized',...
                'Position', [0.88 0.85 0.03 0.03],...
                'Callback', @EditData);
            UndoEditButton = uicontrol('Style', 'pushbutton', 'String', 'Undo',...
                'units','normalized',...
                'Position', [0.91 0.85 0.03 0.03],...
                'Callback', @UndoEdit);            
            DisplayEditsButton = uicontrol('Style', 'togglebutton', 'String', 'DispEd',...
                'value',DisplayEditsOn,...
                'units','normalized',...
                'Position', [0.94 0.85 0.03 0.03],...
                'Callback', @DisplayEdits);
            DisplayEditsFormatButton = uicontrol('Style', 'pushbutton', 'String', 'FormEd',...
                'units','normalized',...
                'Position', [0.97 0.85 0.03 0.03],...
                'Callback', @DisplayEditsFormat);            
            if ~Channel_Info(Channel).Editable
                set(EditDataButton,'Enable','off');
                set(UndoEditButton,'Enable','off');
                set(DisplayEditsButton,'Enable','off');
                set(DisplayEditsFormatButton,'Enable','off');
            else
                set(DisplayEditsButton,'value',DisplayEditsOn)
            end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %Profile
             AddProfileButton = uicontrol('Style', 'togglebutton', 'String', 'AddProfile',...
                'units','normalized',...
                'value',ProfileOn,...
                'Position', [0.9 0.88 0.05 0.03],...
                'Callback', @AddProfile);
             ClearProfileButton = uicontrol('Style', 'togglebutton', 'String', 'ClearProfile',...
                'units','normalized',...
                'value',ProfileOn,...
                'Position', [0.85 0.88 0.05 0.03],...
                'Callback', @ClearProfile);
            if RGB_Stack
                set(AddProfileButton,'Enable','off');
                set(ClearProfileButton,'Enable','off');
            end
set(AddProfileButton,'Enable','off');
set(ClearProfileButton,'Enable','off');
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            PlayMovieButton = uicontrol('Style', 'pushbutton', 'String', 'PlayAVI',...
                'units','normalized',...
                'Position', [0.81 0.63 0.05 0.03],...
                'Callback', @PlayMovie);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %Mask and Overlay Controls
             MaskButton = uicontrol('Style', 'togglebutton', 'String', 'Add Mask',...
                'units','normalized',...
                'value',MaskOn,...
                'Position', [0.95 0.79 0.05 0.03],...
                'Callback', @AddMask);
            if RGB_Stack
                set(MaskButton,'Enable','off');
            end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %Data Region Controls
            DataRegionMaskButton = uicontrol('Style', 'togglebutton', 'String', 'RegionMask',...
                'units','normalized',...
                'value',DataRegionMaskOn,...
                'Position', [0.95 0.73 0.05 0.03],...
                'Callback', @DataRegionMask);
            DataRegionBorderButton = uicontrol('Style', 'togglebutton', 'String', 'RegionBord',...
                'units','normalized',...
                'value',DataRegionBorderOn,...
                'Position', [0.95 0.70 0.05 0.03],...
                'Callback', @DataRegionBorder);
            DataRegionMaskFormatButton = uicontrol('Style', 'pushbutton', 'String', 'RegionFormat',...
                'units','normalized',...
                'Position', [0.95 0.67 0.05 0.03],...
                'Callback', @DataRegionMaskFormat);
            ROIBorders_Button = uicontrol('Style', 'togglebutton', 'String', 'ROIBord',...
                'value',ROIBorders,...
                'units','normalized',...
                'Position', [0.95 0.76 0.05 0.03],...
                'Callback', @DisplayROIBorders);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %Scale Bar
            ScaleBarButton = uicontrol('Style', 'togglebutton', 'String', 'ScaleBar',...
                'units','normalized',...
                'value',ScaleBarOn,...
                'Position', [0.85 0.79 0.05 0.03],...
                'Callback', @AddScaleBar);
            ImageLabelButton = uicontrol('Style', 'togglebutton', 'String', 'ImageLabel',...
                'units','normalized',...
                'value',ImageLabelOn,...
                'Position', [0.90 0.79 0.05 0.03],...
                'Callback', @AddImageLabel);
            ColorBarOverlayButton = uicontrol('Style', 'togglebutton', 'String', 'AddColorBar',...
                'units','normalized',...
                'value',ColorBarOverlayOn,...
                'Position', [0.80 0.79 0.05 0.03],...
                'Callback', @AddColorBarOverlay);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %Trace Controls
            TraceScaleButton = uicontrol('Style', 'togglebutton', 'String', 'Scale/Axes',...
                'value',TraceScaleOn,...
                'units','normalized',...
                'Position', [0 0 0.05 0.025],...
                'Callback', @TraceScaleBar);
            TraceThreshMarkerButton = uicontrol('Style', 'togglebutton', 'String', 'Thresholds',...
                'value',TraceThreshMarkersOn,...
                'units','normalized',...
                'Position', [0.05 0 0.04 0.025],...
                'Callback', @TraceThreshMarkerToggle);
            CurrentFrameMarkerButton = uicontrol('Style', 'togglebutton', 'String', 'Frame',...
                'value',CurrentFrameMarkerOn,...
                'units','normalized',...
                'Position', [0.09 0 0.03 0.025],...
                'Callback', @CurrentFrameMarkerToggle);
            FrameMarkersButton = uicontrol('Style', 'togglebutton', 'String', 'FrameMarkers',...
                'value',FrameMarkersOn,...
                'units','normalized',...
                'Position', [0.12 0 0.05 0.025],...
                'Callback', @FrameMarkersToggle);
            FrameMarkerLabelsButton = uicontrol('Style', 'togglebutton', 'String', 'MarkerLabel',...
                'value',FrameMarkerLabelsOn,...
                'units','normalized',...
                'Position', [0.17 0 0.05 0.025],...
                'Callback', @FrameMarkerLabelsToggle);
            MeanTraces_Button = uicontrol('Style', 'togglebutton', 'String', 'MeanTraces',...
                'value',MeanTraces,...
                'units','normalized',...
                'Position', [0.22 0 0.05 0.025],...
                'Callback', @DisplayMeanTraces);
            SliceMeanTraces_Button = uicontrol('Style', 'togglebutton', 'String', 'SliceTraces',...
                'value',SliceMeanTraces,...
                'units','normalized',...
                'Position', [0.27 0 0.05 0.025],...
                'Callback', @DisplaySliceMeanTraces);
            FormatTraces_Button = uicontrol('Style', 'pushbutton', 'String', 'FormatTrace',...
                'units','normalized',...
                'Position', [0.32 0 0.05 0.025],...
                'Callback', @FormatTraces);
            FormatFrameMarkers_Button = uicontrol('Style', 'pushbutton', 'String', 'FormatMarkers',...
                'units','normalized',...
                'Position', [0.37 0 0.05 0.025],...
                'Callback', @FormatFrameMarkers);
            FormatROIs_Button = uicontrol('Style', 'pushbutton', 'String', 'FormatROI',...
                'units','normalized',...
                'Position', [0.42 0 0.05 0.025],...
                'Callback', @FormatROIs);
            ROITraces_Button = uicontrol('Style', 'togglebutton', 'String', 'ROIs',...
                'value',ROITraces,...
                'units','normalized',...
                'Position', [0.47 0 0.025 0.025],...
                'Callback', @DisplayROITraces);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %ROI controls 
            ResetTraces_Button = uicontrol('Style', 'pushbutton', 'String', 'Reset',...
                'units','normalized',...
                'Position', [0.53 0 0.03 0.025],...
                'Callback', @ResetTrace);   
            UpdateTrace_Pixel_Button = uicontrol('Style', 'pushbutton', 'String', '+Pixel',...
                'units','normalized',...
                'Position', [0.56 0 0.03 0.025],...
                'Callback', @AddPixelTrace);   
            UpdateTrace_ROI_Button = uicontrol('Style', 'pushbutton', 'String', '+ROI',...
                'units','normalized',...
                'Position', [0.59 0 0.03 0.025],...
                'Callback', @AddROITrace);
            UndoROI_Button = uicontrol('Style', 'pushbutton', 'String', 'Undo',...
                'units','normalized',...
                'Position', [0.62 0 0.03 0.025],...
                'Callback', @UndoROI);
            ZoomXTraces_Button = uicontrol('Style', 'pushbutton', 'String', 'ZoomX',...
                'units','normalized',...
                'Position', [0.65 0 0.03 0.025],...
                'Callback', @ZoomXTrace);
            ZoomYTraces_Button = uicontrol('Style', 'pushbutton', 'String', 'ZoomY',...
                'units','normalized',...
                'Position', [0.68 0 0.03 0.025],...
                'Callback', @ZoomYTrace);
            ResetZoomTraces_Button = uicontrol('Style', 'pushbutton', 'String', 'ResetZo',...
                'units','normalized',...
                'Position', [0.71 0 0.04 0.025],...
                'Callback', @ResetZoomTrace);
set(ZoomXTraces_Button,'Enable','off');
set(ZoomYTraces_Button,'Enable','off');
set(ResetZoomTraces_Button,'Enable','off');
            if ~T_Stack||RGB_Stack
                set(ExportTraceButton,'Enable','off');
                set(TraceScaleButton,'Enable','off','value',0);
                set(ResetTraces_Button,'Enable','off');
                set(UpdateTrace_Pixel_Button,'Enable','off');
                set(UpdateTrace_ROI_Button,'Enable','off');
                set(UndoROI_Button,'Enable','off');
                set(MeanTraces_Button,'Enable','off','value',0);
                set(ROIBorders_Button,'Enable','off','value',0);
                set(ROITraces_Button,'Enable','off','value',0);
                set(FormatROIs_Button,'Enable','off');
                set(FormatTraces_Button,'Enable','off');
                set(FormatFrameMarkers_Button,'Enable','off');
                set(CurrentFrameMarkerButton,'Enable','off','value',0);
                set(TraceThreshMarkerButton,'Enable','off','value',0);
                set(SliceMeanTraces_Button,'Enable','off','value',0);
                set(FrameMarkersButton,'Enable','off','value',0);
                set(FrameMarkerLabelsButton,'Enable','off','value',0);
                set(ZoomXTraces_Button,'Enable','off');
                set(ZoomYTraces_Button,'Enable','off');
                set(ResetZoomTraces_Button,'Enable','off');
            end
            if ~Z_Stack||RGB_Stack
                set(SliceMeanTraces_Button,'Enable','off','value',0);
            end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %Histogram Controls
             SliceHistButton = uicontrol('Style', 'togglebutton', 'String', 'Slice',...
                'units','normalized',...
                'value',SliceHist,...
                'Position', [0.79 0.55 0.03 0.025],...
                'Callback', @UpdateLiveHist);   
             OverallHistButton = uicontrol('Style', 'togglebutton', 'String', 'Overall',...
                'units','normalized',...
                'value',OverallHist,...
                'Position', [0.82 0.55 0.03 0.025],...
                'Callback', @UpdateLiveHist);   
             NormHistButton = uicontrol('Style', 'togglebutton', 'String', 'Norm.',...
                'units','normalized',...
                'value',NormHist,...
                'Position', [0.85 0.55 0.03 0.025],...
                'Callback', @UpdateLiveHist);   
             LiveHistButton = uicontrol('Style', 'togglebutton', 'String', 'Live',...
                'units','normalized',...
                'value',LiveHist,...
                'Position', [0.88 0.55 0.03 0.025],...
                'Callback', @UpdateLiveHist);   
             LogXButton = uicontrol('Style', 'togglebutton', 'String', 'LogX',...
                'units','normalized',...
                'value',LogHistX,...
                'Position', [0.91 0.55 0.03 0.025],...
                'Callback', @UpdateHistDisplay);   
             LogYButton = uicontrol('Style', 'togglebutton', 'String', 'LogY',...
                'units','normalized',...
                'value',LogHistY,...
                'Position', [0.94 0.55 0.03 0.025],...
                'Callback', @UpdateHistDisplay);   
             AutoScaleButton = uicontrol('Style', 'togglebutton', 'String', 'Auto',...
                'units','normalized',...
                'value',AutoScaleHist,...
                'Position', [0.97 0.55 0.03 0.025],...
                'Callback', @UpdateHistDisplay);   
            if ~Z_Stack
                set(SliceHistButton,'Enable','off');
            end
            if RGB_Stack
                set(OverallHistButton,'Enable','off');
                set(NormHistButton,'Enable','off');
                set(LiveHistButton,'Enable','off');
                set(LogXButton,'Enable','off');
                set(LogYButton,'Enable','off');
                set(AutoScaleButton,'Enable','off');
            end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %ColorMap
            ColorMapList = uicontrol('Style', 'popup',...
                'String', ColorMapOptions,...
                'units','normalized',...
                'value',Channel_Info(Channel).DisplayColorMapIndex,...
                'Position', [0.86 0.63 0.03 0.03],...
                'Callback', @SetColorMap);    
            if RGB_Stack
                set(ColorMapList,'Enable','off');
            end
            SliceColorButton = uicontrol('Style', 'togglebutton', 'String', 'SliceColor',...
                'units','normalized',...
                'value',SliceColorOn,...
                'Position', [0.81 0.58 0.05 0.03],...
                'Callback', @SliceColor);
set(SliceColorButton,'Enable','off');
            if RGB_Stack||~Z_Stack
                set(SliceColorButton,'Enable','off');
            end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %Labels
            ChannelLabelText = uicontrol('Style', 'edit', 'string',num2str(Channel_Labels{Channel}),...
                'units','normalized',...
                'Position', [0.81 0.61 0.08 0.02]);      
            ChannelLabelButton = uicontrol('Style', 'pushbutton', 'String', 'CLabel',...
                'units','normalized',...
                'Position', [0.86 0.58 0.03 0.03],...
                'Callback', @ChannelLabelUpdate);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %Merge Channels, Project T, Project Z
             MergeChannelButton = uicontrol('Style', 'togglebutton', 'String', 'CMerge',...
                'units','normalized',...
                'value',MergeChannel,...
                'Position', [0.95 0.58 0.03 0.03],...
                'Callback', @MergeChannelSetup);
             TileChannelsButton = uicontrol('Style', 'togglebutton', 'String', 'CTile',...
                'units','normalized',...
                'value',TileChannels,...
                'Position', [0.98 0.58 0.02 0.03],...
                'Callback', @TileChannelsSetup);
             Z_ProjectionButton = uicontrol('Style', 'togglebutton', 'String', 'ZProj',...
                'units','normalized',...
                'value',Z_Projection,...
                'Position', [0.95 0.61 0.03 0.03],...
                'Callback', @Z_ProjectData);
             TileSlicesButton = uicontrol('Style', 'togglebutton', 'String', 'ZTile',...
                'units','normalized',...
                'value',TileSlices,...
                'Position', [0.98 0.61 0.02 0.03],...
                'Callback', @TileSlicesSetup);
             T_ProjectionButton = uicontrol('Style', 'togglebutton', 'String', 'TProj',...
                'units','normalized',...
                'value',T_Projection,...
                'Position', [0.95 0.64 0.03 0.03],...
                'Callback', @T_ProjectData);
             TileFramesButton = uicontrol('Style', 'togglebutton', 'String', 'TTile',...
                'units','normalized',...
                'value',TileFrames,...
                'Position', [0.98 0.64 0.02 0.03],...
                'Callback', @TileFramesSetup);
            if ~T_Stack||RGB_Stack
                set(T_ProjectionButton,'Enable','off');
                set(TileFramesButton,'Enable','off');
            end
            if ~Z_Stack||RGB_Stack
                set(Z_ProjectionButton,'Enable','off');
                set(TileSlicesButton,'Enable','off');
            end
            if ~C_Stack||RGB_Stack
                set(MergeChannelButton,'Enable','off');
                set(TileChannelsButton,'Enable','off');
            end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %Create Frame_Slider
            if T_Stack
                Frame_sld = uicontrol('Style', 'slider',...
                    'Min',1,'Max',Last_T,'Value',1,...
                    'sliderStep',[1/(Last_T-1),10/(Last_T-1)],...
                    'units','normalized',...
                    'Position', [0 0.985 0.7 0.015],...
                    'Callback', @Frame_Slider);
                txt = uicontrol('Style','text',...
                    'units','normalized',...
                    'Position', [0.7 0.985 0.01 0.015],...
                    'String','T');
            end
            %Channel And Slice Sliders
            if Z_Stack&&~C_Stack&&T_Stack
                Channel_sld=[];
                % Create Channel_Slider
                Slice_sld = uicontrol('Style', 'slider',...
                    'Min',1,'Max',Last_Z,'Value',1,...
                    'sliderStep',[1/(Last_Z-1),10/(Last_Z-1)],...
                    'units','normalized',...
                    'Position', [0 0.215 0.015 0.77],...
                    'Callback', @Slice_Slider);
                txt = uicontrol('Style','text',...
                    'units','normalized',...
                    'Position', [0 0.2 0.01 0.015],...
                    'String','Z');
            elseif C_Stack&&~Z_Stack&&T_Stack
                Slice_sld=[];
                Channel_sld = uicontrol('Style', 'slider',...
                    'Min',1,'Max',Last_C,'Value',1,...
                    'sliderStep',[1/(Last_C-1),10/(Last_C-1)],...
                    'units','normalized',...
                    'Position', [0 0.215 0.015 0.77],...
                    'Callback', @Channel_Slider);
                txt = uicontrol('Style','text',...
                    'units','normalized',...
                    'Position', [0 0.2 0.01 0.015],...
                    'String','C');
            elseif Z_Stack&&~C_Stack&&~T_Stack
                Channel_sld=[];
                % Create Channel_Slider
                Slice_sld = uicontrol('Style', 'slider',...
                    'Min',1,'Max',Last_Z,'Value',1,...
                    'sliderStep',[1/(Last_Z-1),10/(Last_Z-1)],...
                    'units','normalized',...
                    'Position', [0 0.04 0.015 0.945],...
                    'Callback', @Slice_Slider);
                txt = uicontrol('Style','text',...
                    'units','normalized',...
                    'Position', [0 0.025 0.01 0.015],...
                    'String','Z');
            elseif C_Stack&&~Z_Stack&&~T_Stack
                Slice_sld=[];
                Channel_sld = uicontrol('Style', 'slider',...
                    'Min',1,'Max',Last_C,'Value',1,...
                    'sliderStep',[1/(Last_C-1),10/(Last_C-1)],...
                    'units','normalized',...
                    'Position', [0 0.04 0.015 0.945],...
                    'Callback', @Channel_Slider);
                txt = uicontrol('Style','text',...
                    'units','normalized',...
                    'Position', [0 0.025 0.01 0.015],...
                    'String','C');
            elseif C_Stack&&Z_Stack&&T_Stack
                % Create Channel_Slider
                Channel_sld = uicontrol('Style', 'slider',...
                    'Min',0,'Max',Last_C,'Value',1,...
                    'sliderStep',[1/(Last_C-1),10/(Last_C-1)],...
                    'units','normalized',...
                    'Position', [0.015 0.215 0.015 0.77],...
                    'Callback', @Channel_Slider);
                txt = uicontrol('Style','text',...
                    'units','normalized',...
                    'Position', [0.015 0.2 0.01 0.015],...
                    'String','C');
                % Create Slice_Slider
                Slice_sld = uicontrol('Style', 'slider',...
                    'Min',0,'Max',Last_Z,'Value',1,...
                    'sliderStep',[1/(Last_Z-1),10/(Last_Z-1)],...
                    'units','normalized',...
                    'Position', [0 0.215 0.015 0.77],...
                    'Callback', @Slice_Slider);
                txt = uicontrol('Style','text',...
                    'units','normalized',...
                    'Position', [0 0.2 0.01 0.015],...
                    'String','Z');
            elseif C_Stack&&Z_Stack&&~T_Stack
                % Create Channel_Slider
                Channel_sld = uicontrol('Style', 'slider',...
                    'Min',0,'Max',Last_C,'Value',1,...
                    'sliderStep',[1/(Last_C-1),10/(Last_C-1)],...
                    'units','normalized',...
                    'Position', [0 0.985 0.7 0.015],...
                    'Callback', @Channel_Slider);
                txt = uicontrol('Style','text',...
                    'units','normalized',...
                    'Position', [0.7 0.985 0.01 0.015],...
                    'String','C');
                % Create Slice_Slider
                Slice_sld = uicontrol('Style', 'slider',...
                    'Min',0,'Max',Last_Z,'Value',1,...
                    'sliderStep',[1/(Last_Z-1),10/(Last_Z-1)],...
                    'units','normalized',...
                    'Position', [0 0.04 0.015 0.945],...
                    'Callback', @Slice_Slider);
                txt = uicontrol('Style','text',...
                    'units','normalized',...
                    'Position', [0 0.025 0.01 0.015],...
                    'String','Z');
            else
                Slice_sld=[];
                Channel_sld=[];
            end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Create Contrast Sliders
            High_sld = uicontrol('Style', 'slider',...
                'Min',0,'Max',1,'Value',Channel_Info(Channel).Normalized_Display_Limits(2),...
                'sliderStep',Channel_Info(Channel).Normalized_StepUnits,...
                'units','normalized',...
                'Position', [0.92 0.67 0.03 0.12],...
                'Callback', @HighContrast);
            HighDisp = uicontrol('Style', 'edit', 'string',num2str(Channel_Info(Channel).Display_Limits(2)),...
                'units','normalized',...
                'Position', [0.92 0.64 0.03 0.03]);      
            HighButton = uicontrol('Style', 'pushbutton', 'String', 'High^',...
                'units','normalized',...
                'Position', [0.92 0.61 0.03 0.03],...
                'Callback', @SetHighContrast);
            Low_sld = uicontrol('Style', 'slider',...
                'Min',0,'Max',1,'Value',Channel_Info(Channel).Normalized_Display_Limits(1),...
                'sliderStep',Channel_Info(Channel).Normalized_StepUnits,...
                'units','normalized',...
                'Position', [0.89 0.67 0.03 0.12],...
                'Callback', @LowContrast);
            LowDisp = uicontrol('Style', 'edit', 'string',num2str(Channel_Info(Channel).Display_Limits(1)),...
                'units','normalized',...
                'Position', [0.89 0.64 0.03 0.03]);      
            LowButton = uicontrol('Style', 'pushbutton', 'String', 'Low^',...
                'units','normalized',...
                'Position', [0.89 0.61 0.03 0.03],...
                'Callback', @SetLowContrast);
            AutoContButton = uicontrol('Style', 'togglebutton', 'String', 'AutoC',...
                'units','normalized',...
                'value',AutoContrastOn,...
                'Position', [0.92 0.58 0.03 0.03],...
                'Callback', @AutoContrast);
set(AutoContButton,'Enable','off')
            LinkContButton = uicontrol('Style', 'pushbutton', 'String', 'LinkC',...
                'units','normalized',...
                'Position', [0.89 0.58 0.03 0.03],...
                'Callback', @LinkContrast);
            if RGB_Stack
                set(High_sld,'Enable','off');
                set(HighDisp,'Enable','off');
                set(HighButton,'Enable','off');
                set(Low_sld,'Enable','off');
                set(LowDisp,'Enable','off');
                set(LowButton,'Enable','off');
                set(AutoContButton,'Enable','off');
            end
            if ~C_Stack||RGB_Stack
                set(LinkContButton,'Enable','off');
            end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ViewerFig,'WindowKeyPressFcn',@Navigation_KeyPressFcn);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if ~isempty(EditRecord)
       	warning([num2str(length(EditRecord)),' Edits were imported! Do you want to use?'])
        ApplyEdits = questdlg({[num2str(length(EditRecord)),' Edits were imported!'];'Do you want to use all or Reset EditRecord?'},...
            'Apply Previous Edits?','Apply','Reset','Reset');
        switch ApplyEdits
            case 'Apply'
                DisplayEditsOn=1;
                fprintf(['Applying ',num2str(length(EditRecord)),'...'])
                for e=1:length(EditRecord)
                    Channel=EditRecord(e).Channel;
                    Frame=EditRecord(e).Frame;
                    Slice=EditRecord(e).Slice;
                    Channel_Info(Channel).Editable=1;
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    %UpdateDisplay
                    CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                    [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    if ~RGB_Stack
                        if T_Stack
                            TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                        end
                        if LiveHist
                            HistDisplay(HistAxis,HistAxisPosition);
                        end
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    [EditRecord(e).EditRegion,EditRecord(e).EditData,EditRecord(e).EditRegionBorderLine]=...
                        ApplyEdit(EditRecord(e).EditRegion,EditRecord(e).Channel,EditRecord(e).Frame,EditRecord(e).Slice,StackOrder,EditRecord(e).EditMode);
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    %UpdateDisplay
                    CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                    [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    if ~RGB_Stack
                        if T_Stack
                            TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                        end
                        if LiveHist
                            HistDisplay(HistAxis,HistAxisPosition);
                        end
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    pause(1);
                end
                fprintf('Finished!\n')
            case 'Reset'
                EditRecord=[];
        end
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        fprintf('Ready!\n')
        if ReleaseFig
            if NumOutputArgs==0
            end
            if NumOutputArgs>=1
                varargout{1}=ViewerFig;
            end
            if NumOutputArgs>=2
                varargout{2}=Channel_Info;
            end
            if NumOutputArgs>=3
                varargout{3}=OutputAnalysis;
            end
            if NumOutputArgs>=4
                varargout{4}=EditRecord;
            end
            if NumOutputArgs>=5
                varargout{5}=[];
            end
        else
            disp('To continue please exit script when done <End>/<Escape>')
            uiwait(ViewerFig);
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function Navigation_KeyPressFcn(~, evnt)
            figure(ViewerFig)
            CurrentObject=get(ViewerFig,'CurrentObject');
            if ~isa(CurrentObject,'matlab.ui.control.UIControl')
                if isequal(evnt.Key,'rightarrow')
                    if T_Stack
                        FrameAdvance;
                    elseif C_Stack&&Z_Stack
                        ChannelUp;
                    end
                elseif isequal(evnt.Key,'leftarrow')
                    if T_Stack
                        FrameRetreat;
                    elseif C_Stack&&Z_Stack
                        ChannelDown;
                    end
                elseif isequal(evnt.Key,'+')
                    ReduceContrast;
                elseif isequal(evnt.Key,'-')
                    EnhanceContrast;
                elseif isequal(evnt.Key,'uparrow')
                    if ~Z_Stack&&~C_Stack
                        if ~RGB_Stack
                            ReduceContrast;
                        end
                    elseif Z_Stack&&~C_Stack
                        SliceUp;
                    elseif C_Stack&&~Z_Stack
                        ChannelUp;
                    elseif C_Stack&&Z_Stack
                        SliceUp;
                    end
                elseif isequal(evnt.Key,'downarrow')
                    if ~Z_Stack&&~C_Stack
                        if ~RGB_Stack
                            EnhanceContrast;
                        end
                    elseif Z_Stack&&~C_Stack
                        SliceDown;
                    elseif C_Stack&&~Z_Stack
                        ChannelDown;
                    elseif C_Stack&&Z_Stack
                        SliceDown;
                    end
                elseif isequal(evnt.Key,'pageup')
                    if C_Stack
                        ChannelUp;
                    end
                elseif isequal(evnt.Key,'pagedown')
                    if C_Stack
                        ChannelDown;
                    end
                elseif isequal(evnt.Key,'space')
                    if PlayBack
                        PausePlayStack(PauseButton);
                    else
                        StartPlayStack(PlayButton);
                    end
                elseif isequal(evnt.Key,'control')
                    ZoomIn
                elseif isequal(evnt.Key,'home')
                    ZoomReset
                elseif isequal(evnt.Key,'shift')
                    FlagFrame
                elseif isequal(evnt.Key,'insert')
                    AddLocalization
                elseif isequal(evnt.Key,'delete')
                    DeleteLocalization
                elseif isequal(evnt.Key,'x')
                    EditData
                elseif isequal(evnt.Key,'z')
                    UndoEdit
                elseif isequal(evnt.Key,'alt')
                    MakeChannelEditable
                elseif isequal(evnt.Key,'end')||isequal(evnt.Key,'escape')
                    ExitStackViewer;
                end
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function ViewInstructions(~,~,~)
            set(InstructButton, 'Enable', 'off');
            questdlg(Instructions,'Instructions!','Continue','Continue');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(InstructButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function Prompt(PromptText,PromptViewerFigPosition)
            warning off
            if iscell(PromptText)
                for p=1:length(PromptText)
                    fprintf([PromptText{p},' '])
                end
            else
                fprintf(PromptText)
            end
            warning on
            PromptFig=figure('position',PromptViewerFigPosition);
            PromptFigText = uicontrol('Units','Normalized','Position', [0 0.3 1 0.7],'style','text',...
                'string',PromptText,'BackgroundColor','w','fontsize',12);
            PromptFigButton = uicontrol('Units','Normalized','Position', [0 0 1 0.3],'style','push',...
                'string','Continue','callback','close(gcf)', ...
                'userdata',0,'fontsize',12);
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function ReleaseFigure(~,~,~)
            disp('Releasing Figure...');
            ReleaseFig=1;
            figure(ViewerFig)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            PlayBack=0;
            pause(0.1);
            set(ReleaseFigureButton,'enable','off')
            DataOutput
            uiresume(ViewerFig);
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
        function ExitStackViewer(~,~,~)
            ExitViewer=1;
            figure(ViewerFig)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            PlayBack=0;
            pause(0.1);
            DataOutput;
            uiresume(ViewerFig);
            close(ViewerFig);
            try
                close(TrackerFig);
            catch
            end
            disp('Exiting Stack Viewer...Come back again soon!')
            disp('=============================================================================================');
            disp('=============================================================================================');
        end
        function DataOutput
            if NumOutputArgs==0
            end
            if NumOutputArgs>=1
                varargout{1}=ViewerFig;
            end
            if NumOutputArgs>=2
                varargout{2}=Channel_Info;
            end
            if NumOutputArgs>=3
                varargout{3}=ImagingInfo;
            end
            if NumOutputArgs>=4
                if ~isempty(OutputAnalysis)
                    warning([num2str(length(OutputAnalysis)),' Analyses were Performed! Do you want to SAVE the OutputAnalysis?'])
                    SaveAnalysis = questdlg({[num2str(length(OutputAnalysis)),' Analyses were Performed!'];'Do you want to SAVE or CLEAR OutputAnalysis?'},...
                        'Save OutputAnalysis?','Save','Clear','Save');
                    switch SaveAnalysis
                        case 'Save'
                            OutputAnalysis.LocalizationMarkers=LocalizationMarkers;
                            OutputAnalysis.ROIs=ROIs;
                            OutputAnalysis.EditRecord=EditRecord;
                            OutputAnalysis.Tracker_Z_Data=Tracker_Z_Data;
                            OutputAnalysis.Tracker_T_Data=Tracker_T_Data;
                            OutputAnalysis.Locations=Locations;
                            OutputAnalysis.ProfileInfo=ProfileInfo;
                            OutputAnalysis.FrameMarkers=FrameMarkers;
                            OutputAnalysis.ExportSettings=ExportSettings;
                            OutputAnalysis.TileSettings=TileSettings;
                            OutputAnalysis.Z_ProjectionSettings=Z_ProjectionSettings;
                            OutputAnalysis.T_ProjectionSettings=T_ProjectionSettings;
                            OutputAnalysis.ScaleBar=ScaleBar;
                            OutputAnalysis.ZoomScaleBar=ZoomScaleBar;
                            OutputAnalysis.ColorBarOverlay=ColorBarOverlay;
                            OutputAnalysis.MergeChannel=MergeChannel;
                            OutputAnalysis.LiveMerge=LiveMerge;
                            OutputAnalysis.Channels2Merge=Channels2Merge;
                            OutputAnalysis.ImageLabel=ImageLabel;
                            OutputAnalysis.ZoomImageLabel=ZoomImageLabel;
                        case 'Clear'
                            OutputAnalysis=[];
                    end
                end
                varargout{4}=OutputAnalysis;
            end
            if NumOutputArgs>=5
                 if ~isempty(EditRecord)
                    SaveEditedImageArray = questdlg({'Do you also want to SAVE the Edited ImageArray?'},...
                        'Save Edited ImageArray?','Save','Clear','Save');
                    switch SaveEditedImageArray
                        case 'Save'
                            varargout{5}=ImageArray;
                        case 'Clear'
                            varargout{5}=[];
                    end
                 else
                    varargout{5}=[];
                 end
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function CollectImagingInfo
            if isempty(ImagingInfo)
                ImagingInfo.PixelSize=0.25;
                ImagingInfo.PixelUnit='um';
                if Z_Stack
                    ImagingInfo.VoxelDepth=0.5;
                    ImagingInfo.VoxelUnit='um';
                else
                    ImagingInfo.VoxelDepth=NaN;
                    ImagingInfo.VoxelUnit=[''];
                end
                if T_Stack
                    ImagingInfo.InterFrameTime=0.050;
                    ImagingInfo.FrameUnit='s';
                else
                    ImagingInfo.InterFrameTime=NaN;
                    ImagingInfo.FrameUnit=[''];
                end
            end
            prompt = {'ImagingInfo.PixelSize (length per pixel)','ImagingInfo.PixelUnit {ex um nm)'};
            dlg_title = 'ImagingInfo Pixel Info';
            num_lines = 1;
            def = {num2str(ImagingInfo.PixelSize),ImagingInfo.PixelUnit};
            answer = inputdlg(prompt,dlg_title,num_lines,def);
            ImagingInfo.PixelSize=         str2num(answer{1});
            ImagingInfo.PixelUnit=                  answer{2};
            if Z_Stack
                prompt = {'ImagingInfo.VoxelDepth (Distance btw slices)','ImagingInfo.VoxelUnit {ex um nm)'};
                dlg_title = 'ImagingInfo Z Info';
                num_lines = 1;
                def = {num2str(ImagingInfo.VoxelDepth),ImagingInfo.VoxelUnit};
                answer = inputdlg(prompt,dlg_title,num_lines,def);
                ImagingInfo.VoxelDepth=         str2num(answer{1});
                ImagingInfo.VoxelUnit=                  answer{2};
            end
            if T_Stack
                prompt = {'ImagingInfo.InterFrameTime (Time between frames)','ImagingInfo.FrameUnit {ex s ms)'};
                dlg_title = 'ImagingInfo T Info';
                num_lines = 1;
                def = {num2str(ImagingInfo.InterFrameTime),ImagingInfo.FrameUnit};
                answer = inputdlg(prompt,dlg_title,num_lines,def);
                ImagingInfo.InterFrameTime=         str2num(answer{1});
                ImagingInfo.FrameUnit=                  answer{2};
            end
            clear answer
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function CurrentImages=FindCurrentImage(Temp_Channel_Input,Temp_Frame_Input,Temp_Slice_Input,StackOrder,...
            Temp_Z_Projection_Input,Temp_T_Projection_Input,Temp_MergeChannel_Input,Temp_OverwriteMerge_Input,...
            TileTemp_Channels,TileTemp_Slices,TileTemp_Frames,TileSettings)
            CurrentImages=[];
            if TileTemp_Channels
                Images=length(TileSettings.C_Range);
                for i=1:Images
                    Temp_Channel_List(i)=TileSettings.C_Range(i);
                    Temp_Frame_List(i)=Temp_Frame_Input;
                    Temp_Slice_List(i)=Temp_Slice_Input;
                    if TileSettings.C_Range(i)==-1
                        Temp_Z_Projection_List(i)=1;
                    else
                        Temp_Z_Projection_List(i)=0;
                    end
                    if TileSettings.C_Range(i)==-2
                        Temp_T_Projection_List(i)=1;
                    else
                        Temp_T_Projection_List(i)=0;
                    end
                    if TileSettings.C_Range(i)<=0
                        Temp_MergeChannel_List(i)=1;
                    else
                        Temp_MergeChannel_List(i)=0;
                    end
                    Temp_OverwriteMerge_List(i)=0;
                end
            elseif TileTemp_Slices
                Images=length(TileSettings.Z_Range);
                for i=1:Images
                    Temp_Channel_List(i)=Temp_Channel_Input;
                    Temp_Frame_List(i)=Temp_Frame_Input;
                    Temp_Slice_List(i)=TileSettings.Z_Range(i);
                    if TileSettings.Z_Range(i)==0
                        Temp_Z_Projection_List(i)=1;
                    else
                        Temp_Z_Projection_List(i)=0;
                    end
                    if Temp_T_Projection_Input
                        Temp_T_Projection_List(i)=1;
                    else
                        Temp_T_Projection_List(i)=0;
                    end
                    if Temp_MergeChannel_Input
                        Temp_MergeChannel_List(i)=1;
                    else
                        Temp_MergeChannel_List(i)=0;
                    end
                    Temp_OverwriteMerge_List(i)=0;
                end
            elseif TileTemp_Frames
                Images=length(TileSettings.T_Range);
                for i=1:Images
                    Temp_Channel_List(i)=Temp_Channel_Input;
                    Temp_Frame_List(i)=TileSettings.T_Range(i);
                    Temp_Slice_List(i)=Temp_Slice_Input;
                    if Temp_Z_Projection_Input
                        Temp_Z_Projection_List(i)=1;
                    else
                        Temp_Z_Projection_List(i)=0;
                    end
                    if TileSettings.T_Range(i)==0
                        Temp_T_Projection_List(i)=1;
                    else
                        Temp_T_Projection_List(i)=0;
                    end
                    if Temp_MergeChannel_Input
                        Temp_MergeChannel_List(i)=1;
                    else
                        Temp_MergeChannel_List(i)=0;
                    end
                    Temp_OverwriteMerge_List(i)=0;
                end
            else
                Images=1;
                i=1;
                Temp_Channel_List(i)=Temp_Channel_Input;
                Temp_Frame_List(i)=Temp_Frame_Input;
                Temp_Slice_List(i)=Temp_Slice_Input;
                Temp_Z_Projection_List(i)=Temp_Z_Projection_Input;
                Temp_T_Projection_List(i)=Temp_T_Projection_Input;
                if isempty(Temp_MergeChannel_Input)
                    Temp_MergeChannel_List(i)=0;
                else
                    Temp_MergeChannel_List(i)=Temp_MergeChannel_Input;
                end
                if isempty(Temp_OverwriteMerge_Input)
                    Temp_OverwriteMerge_List(i)=0;
                else
                    Temp_OverwriteMerge_List(i)=Temp_OverwriteMerge_Input;
                end
            end
            for i=1:Images
                Temp_Channel=Temp_Channel_List(i);
                Temp_Frame=Temp_Frame_List(i);
                Temp_Slice=Temp_Slice_List(i);
                Temp_Z_Projection=Temp_Z_Projection_List(i);
                Temp_T_Projection=Temp_T_Projection_List(i);
                Temp_MergeChannel=Temp_MergeChannel_List(i);
                Temp_OverwriteMerge=Temp_OverwriteMerge_List(i);
                CurrentImages(i).RGB_Stack=RGB_Stack;
                CurrentImages(i).Channel=Temp_Channel;
                CurrentImages(i).Slice=Temp_Slice;
                CurrentImages(i).Frame=Temp_Frame;
                CurrentImages(i).Z_Projection=0;
                CurrentImages(i).T_Projection=0;
                CurrentImages(i).MergeChannel=0;
                CurrentImages(i).RGBOn=0;
                CurrentImages(i).MaskOn=0;
                if Temp_Z_Projection&&~Temp_T_Projection
                    if ~Temp_MergeChannel||Temp_OverwriteMerge
                        CurrentImage=Z_Projection_Data(Temp_Channel,Temp_Frame).Proj;
                        CurrentImages(i).Z_Projection=1;
                        CurrentImages(i).RGBOn=0;
                        if MaskOn
                            CurrentImages(i).MaskOn=1;
                        end
                    else
                        CurrentImage=Z_Projection_Merge_Data(Temp_Frame).Proj;
                        CurrentImages(i).Z_Projection=1;
                        CurrentImages(i).MergeChannel=1;
                        CurrentImages(i).RGBOn=1;
                    end
                elseif Temp_T_Projection&&~Temp_Z_Projection
                    if ~Temp_MergeChannel||Temp_OverwriteMerge
                        CurrentImage=T_Projection_Data(Temp_Channel,Temp_Slice).Proj;
                        CurrentImages(i).T_Projection=1;
                        CurrentImages(i).RGBOn=0;
                        if MaskOn
                            CurrentImages(i).MaskOn=1;
                        end
                    else
                        CurrentImage=T_Projection_Merge_Data(Temp_Slice).Proj;
                        CurrentImages(i).T_Projection=1;
                        CurrentImages(i).MergeChannel=1;
                        CurrentImages(i).RGBOn=1;
                    end
                elseif Temp_T_Projection&&Temp_Z_Projection
                    if ~Temp_MergeChannel||Temp_OverwriteMerge
                        error('Not currently possible!')
                    else
                        error('Not currently possible!')
                    end
                else
                    if ~Temp_MergeChannel||Temp_OverwriteMerge
                        if MaskOn
                            CurrentImages(i).MaskOn=1;
                        end
                        switch StackOrder
                            case 'YXT'
                                CurrentImage=ImageArray(:,:,Temp_Frame);
                                CurrentImages(i).RGBOn=0;
                            case 'YXZ'
                                CurrentImage=ImageArray(:,:,Temp_Slice);
                                CurrentImages(i).RGBOn=0;
                            case 'YXC'
                                CurrentImage=ImageArray(:,:,Temp_Channel);
                                CurrentImages(i).RGBOn=0;
                            case 'YXZT'
                                CurrentImage=ImageArray(:,:,Temp_Slice,Temp_Frame);
                                CurrentImages(i).RGBOn=0;
                            case 'YXTZ'
                                CurrentImage=ImageArray(:,:,Temp_Frame,Temp_Slice);
                                CurrentImages(i).RGBOn=0;
                            case 'YXTC'
                                CurrentImage=ImageArray(:,:,Temp_Frame,Temp_Channel);
                                CurrentImages(i).RGBOn=0;
                            case 'YXCT'
                                CurrentImage=ImageArray(:,:,Temp_Channel,Temp_Frame);
                                CurrentImages(i).RGBOn=0;
                            case 'YXZC'
                                CurrentImage=ImageArray(:,:,Temp_Slice,Temp_Channel);
                                CurrentImages(i).RGBOn=0;
                            case 'YXCZ'
                                CurrentImage=ImageArray(:,:,Temp_Channel,Temp_Slice);
                                CurrentImages(i).RGBOn=0;
                            case 'YXZTC'
                                CurrentImage=ImageArray(:,:,Temp_Slice,Temp_Frame,Temp_Channel);
                                CurrentImages(i).RGBOn=0;
                            case 'YXTZC'
                                CurrentImage=ImageArray(:,:,Temp_Frame,Temp_Slice,Temp_Channel);
                                CurrentImages(i).RGBOn=0;
                            case 'YX[RGB]T'
                                CurrentImage=ImageArray(:,:,:,Temp_Frame);
                                CurrentImages(i).RGBOn=1;
                            case 'YXT[RGB]'
                                CurrentImage=ImageArray(:,:,Temp_Frame,:);
                                CurrentImages(i).RGBOn=1;
                        end
                    elseif Temp_MergeChannel&&LiveMerge
                        CurrentImages(i).MergeChannel=1;
                        switch StackOrder
    %                         case 'YXT'
    %                             CurrentImage=ImageArray(:,:,Temp_Frame);
    %                             CurrentImages(i).RGBOn=0;
    %                         case 'YXZ'
    %                             CurrentImage=ImageArray(:,:,Temp_Slice);
    %                             CurrentImages(i).RGBOn=0;
                            case 'YXC'
                                CurrentImage=zeros(ImageHeight,ImageWidth,3,'single');
                                for c1=1:length(Channels2Merge)
                                    c=Channels2Merge(c1);
                                    CurrentImage1=ImageArray(:,:,c);
                                    CurrentImage1=squeeze(CurrentImage1);
                                    [CurrentImage1]=Stack_Viewer_Adjust_Contrast_and_Color(CurrentImage1,...
                                        Channel_Info(c).ColorMap,...
                                        Channel_Info(c).ContrastLow,...
                                        Channel_Info(c).ContrastHigh,...
                                        Channel_Info(c).ValueAdjust,...
                                        Channel_Info(c).ColorScalar);
                                    CurrentImage=CurrentImage+CurrentImage1;
                                    clear CurrentImage1
                                end
                                CurrentImages(i).RGBOn=1;
    %                         case 'YXZT'
    %                             CurrentImage=ImageArray(:,:,Temp_Slice,Temp_Frame);
    %                             CurrentImages(i).RGBOn=0;
    %                         case 'YXTZ'
    %                             CurrentImage=ImageArray(:,:,Temp_Frame,Temp_Slice);
    %                             CurrentImages(i).RGBOn=0;
                            case 'YXTC'
                                CurrentImage=zeros(ImageHeight,ImageWidth,3,'single');
                                for c1=1:length(Channels2Merge)
                                    c=Channels2Merge(c1);
                                    CurrentImage1=ImageArray(:,:,Temp_Frame,c);
                                    CurrentImage1=squeeze(CurrentImage1);
                                    [CurrentImage1]=Stack_Viewer_Adjust_Contrast_and_Color(CurrentImage1,...
                                        Channel_Info(c).ColorMap,...
                                        Channel_Info(c).ContrastLow,...
                                        Channel_Info(c).ContrastHigh,...
                                        Channel_Info(c).ValueAdjust,...
                                        Channel_Info(c).ColorScalar);
                                    CurrentImage=CurrentImage+CurrentImage1;
                                    clear CurrentImage1
                                end
                                CurrentImages(i).RGBOn=1;
                            case 'YXCT'
                                CurrentImage=zeros(ImageHeight,ImageWidth,3,'single');
                                for c1=1:length(Channels2Merge)
                                    c=Channels2Merge(c1);
                                    CurrentImage1=ImageArray(:,:,c,Temp_Frame);
                                    CurrentImage1=squeeze(CurrentImage1);
                                    [CurrentImage1]=Stack_Viewer_Adjust_Contrast_and_Color(CurrentImage1,...
                                        Channel_Info(c).ColorMap,...
                                        Channel_Info(c).ContrastLow,...
                                        Channel_Info(c).ContrastHigh,...
                                        Channel_Info(c).ValueAdjust,...
                                        Channel_Info(c).ColorScalar);
                                    CurrentImage=CurrentImage+CurrentImage1;
                                    clear CurrentImage1
                                end
                                CurrentImages(i).RGBOn=1;
                            case 'YXZC'
                                CurrentImage=zeros(ImageHeight,ImageWidth,3,'single');
                                for c1=1:length(Channels2Merge)
                                    c=Channels2Merge(c1);
                                    CurrentImage1=ImageArray(:,:,Temp_Slice,c);
                                    CurrentImage1=squeeze(CurrentImage1);
                                    [CurrentImage1]=Stack_Viewer_Adjust_Contrast_and_Color(CurrentImage1,...
                                        Channel_Info(c).ColorMap,...
                                        Channel_Info(c).ContrastLow,...
                                        Channel_Info(c).ContrastHigh,...
                                        Channel_Info(c).ValueAdjust,...
                                        Channel_Info(c).ColorScalar);
                                    CurrentImage=CurrentImage+CurrentImage1;
                                    clear CurrentImage1
                                end
                                CurrentImages(i).RGBOn=1;
                            case 'YXCZ'
                                CurrentImage=zeros(ImageHeight,ImageWidth,3,'single');
                                for c1=1:length(Channels2Merge)
                                    c=Channels2Merge(c1);
                                    CurrentImage1=ImageArray(:,:,c,Temp_Slice);
                                    CurrentImage1=squeeze(CurrentImage1);
                                    [CurrentImage1]=Stack_Viewer_Adjust_Contrast_and_Color(CurrentImage1,...
                                        Channel_Info(c).ColorMap,...
                                        Channel_Info(c).ContrastLow,...
                                        Channel_Info(c).ContrastHigh,...
                                        Channel_Info(c).ValueAdjust,...
                                        Channel_Info(c).ColorScalar);
                                    CurrentImage=CurrentImage+CurrentImage1;
                                    clear CurrentImage1
                                end
                                CurrentImages(i).RGBOn=1;
                            case 'YXZTC'
                                CurrentImage=zeros(ImageHeight,ImageWidth,3,'single');
                                for c1=1:length(Channels2Merge)
                                    c=Channels2Merge(c1);
                                    CurrentImage1=ImageArray(:,:,Temp_Slice,Temp_Frame,c);
                                    CurrentImage1=squeeze(CurrentImage1);
                                    [CurrentImage1]=Stack_Viewer_Adjust_Contrast_and_Color(CurrentImage1,...
                                        Channel_Info(c).ColorMap,...
                                        Channel_Info(c).ContrastLow,...
                                        Channel_Info(c).ContrastHigh,...
                                        Channel_Info(c).ValueAdjust,...
                                        Channel_Info(c).ColorScalar);
                                    CurrentImage=CurrentImage+CurrentImage1;
                                    clear CurrentImage1
                                end
                                CurrentImages(i).RGBOn=1;
                            case 'YXTZC'
                                CurrentImage=zeros(ImageHeight,ImageWidth,3,'single');
                                for c1=1:length(Channels2Merge)
                                    c=Channels2Merge(c1);
                                    CurrentImage1=ImageArray(:,:,Temp_Frame,Temp_Slice,c);
                                    CurrentImage1=squeeze(CurrentImage1);
                                    [CurrentImage1]=Stack_Viewer_Adjust_Contrast_and_Color(CurrentImage1,...
                                        Channel_Info(c).ColorMap,...
                                        Channel_Info(c).ContrastLow,...
                                        Channel_Info(c).ContrastHigh,...
                                        Channel_Info(c).ValueAdjust,...
                                        Channel_Info(c).ColorScalar);
                                    CurrentImage=CurrentImage+CurrentImage1;
                                    clear CurrentImage1
                                end
                                CurrentImages(i).RGBOn=1;
    %                         case 'YX[RGB]T'
    %                             CurrentImage=ImageArray(:,:,:,Temp_Frame);
    %                             CurrentImages(i).RGBOn=1;
    %                         case 'YXT[RGB]'
    %                             CurrentImage=ImageArray(:,:,Temp_Frame,:);
    %                             CurrentImages(i).RGBOn=1;
                        end
                    elseif Temp_MergeChannel&&~LiveMerge
                        CurrentImages(i).MergeChannel=1;
                        CurrentImages(i).RGBOn=1;
                        switch StackOrder
                            case 'YXC'
                                CurrentImage=MergeStack(:,:,:);
                            case 'YXT'
                                CurrentImage=MergeStack(:,:,:,Temp_Frame);
                            case 'YXZ'
                                CurrentImage=MergeStack(:,:,:,Temp_Slice);
                            case 'YXTC'
                                CurrentImage=MergeStack(:,:,:,Temp_Frame);
                            case 'YXCT'
                                CurrentImage=MergeStack(:,:,:,Temp_Frame);
                            case 'YXZC'
                                CurrentImage=MergeStack(:,:,:,Temp_Slice);
                            case 'YXCZ'
                                CurrentImage=MergeStack(:,:,:,Temp_Slice);
                            case 'YXTZC'
                                CurrentImage=MergeStack(:,:,:,Temp_Frame,Temp_Slice);
                            case 'YXZTC'
                                CurrentImage=MergeStack(:,:,:,Temp_Frame,Temp_Slice);
                        end
                    else
                        error('Unable to generate this image...')
                    end
                    if ~exist('CurrentImage')
                        error('We have come across a Stack Order I am not prepared for!')
                    end
                    CurrentImage=squeeze(CurrentImage);
                end
                if ~Temp_OverwriteMerge&&~CurrentImages(i).RGBOn
                    if Temp_Z_Projection&&~Temp_T_Projection&&~CurrentImages(i).RGBOn
                        if ~Temp_MergeChannel%||Temp_OverwriteMerge
                            [CurrentImage]=Stack_Viewer_Adjust_Contrast_and_Color(CurrentImage,...
                                Channel_Info(Temp_Channel).Z_Projection_Data.ColorMaps.ColorMap,...
                                Channel_Info(Temp_Channel).Z_Projection_Data.ContrastLow,...
                                Channel_Info(Temp_Channel).Z_Projection_Data.ContrastHigh,...
                                Channel_Info(Temp_Channel).Z_Projection_Data.ValueAdjust,...
                                Channel_Info(Temp_Channel).ColorScalar);
                            CurrentImages(i).RGBOn=1;
                        else
                            error('You are somewhere you shouldnt be...')
                        end
                    elseif Temp_T_Projection&&~Temp_Z_Projection&&~CurrentImages(i).RGBOn
                        if ~Temp_MergeChannel%||Temp_OverwriteMerge
                            [CurrentImage]=Stack_Viewer_Adjust_Contrast_and_Color(CurrentImage,...
                                Channel_Info(Temp_Channel).T_Projection_Data.ColorMaps.ColorMap,...
                                Channel_Info(Temp_Channel).T_Projection_Data.ContrastLow,...
                                Channel_Info(Temp_Channel).T_Projection_Data.ContrastHigh,...
                                Channel_Info(Temp_Channel).T_Projection_Data.ValueAdjust,...
                                Channel_Info(Temp_Channel).ColorScalar);
                            CurrentImages(i).RGBOn=1;
                        else
                            error('You are somewhere you shouldnt be...')
                        end
                    elseif Temp_T_Projection&&Temp_Z_Projection
                        error('You are somewhere you shouldnt be...')
                    end
                end
                if DataRegionMaskOn&&~Temp_OverwriteMerge
                    if ~CurrentImages(i).RGBOn
                        [CurrentImage]=Stack_Viewer_Adjust_Contrast_and_Color(CurrentImage,...
                            Channel_Info(Temp_Channel).ColorMap,...
                            Channel_Info(Temp_Channel).ContrastLow,...
                            Channel_Info(Temp_Channel).ContrastHigh,...
                            Channel_Info(Temp_Channel).ValueAdjust,...
                            Channel_Info(Temp_Channel).ColorScalar);
                        CurrentImages(i).RGBOn=1;
                    end
                    CurrentImage=AddDataRegionMask(CurrentImage,Temp_Channel,Temp_Frame,Temp_Slice,StackOrder,Temp_Z_Projection,Temp_T_Projection,Temp_MergeChannel,CurrentImages(i).RGBOn);
                end
                if ColorBarOverlayOn&&~Temp_MergeChannel
                    if ~CurrentImages(i).RGBOn
                        [CurrentImage]=Stack_Viewer_Adjust_Contrast_and_Color(CurrentImage,...
                            Channel_Info(Temp_Channel).ColorMap,...
                            Channel_Info(Temp_Channel).ContrastLow,...
                            Channel_Info(Temp_Channel).ContrastHigh,...
                            Channel_Info(Temp_Channel).ValueAdjust,...
                            Channel_Info(Temp_Channel).ColorScalar);
                        CurrentImages(i).RGBOn=1;
                    end
                    CurrentImage=Stack_Viewer_ColorBarEmbedding(CurrentImage,ColorBarOverlay,Temp_Channel);
                end
                CurrentImages(i).CurrentImage=CurrentImage;
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function CurrentImage=AddDataRegionMask(CurrentImage,Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,RGBOn)
            if DataRegionMaskOn
                if ~isempty(DataRegion)
                    if length(size(DataRegion))>2
                        switch StackOrder
                            case 'YXT'
                                DataRegionMask=DataRegion(:,:,Frame);
                            case 'YXZ'
                                if Z_Projection
                                    DataRegionMask=max(DataRegion,[],Z_Dim);
                                else
                                    DataRegionMask=DataRegion(:,:,Slice);
                                end
                            case 'YXC'
                                if MergeChannel
                                    DataRegionMask=max(DataRegion,[],C_Dim);
                                else
                                    DataRegionMask=DataRegion(:,:,Channel);
                                end
                            case 'YXZT'
                                if Z_Projection
                                    DataRegionMask=max(DataRegion(:,:,:,Frame),[],Z_Dim);
                                elseif T_Projection
                                    DataRegionMask=max(DataRegion(:,:,Slice,:),[],T_Dim);
                                else
                                    DataRegionMask=DataRegion(:,:,Slice,Frame);
                                end
                            case 'YXTZ'
                                if Z_Projection
                                    DataRegionMask=max(DataRegion(:,:,Frame,:),[],Z_Dim);
                                elseif T_Projection
                                    DataRegionMask=max(DataRegion(:,:,:,Slice),[],T_Dim);
                                else
                                    DataRegionMask=DataRegion(:,:,Frame,Slice);
                                end
                            case 'YXTC'
                                if T_Projection&&MergeChannel
                                    DataRegionMask=max(max(DataRegion,[],T_Dim),[],C_Dim);
                                elseif T_Projection&&~MergeChannel
                                    DataRegionMask=max(DataRegion(:,:,:,Channel),[],T_Dim);
                                elseif ~T_Projection&&MergeChannel
                                    DataRegionMask=max(DataRegion(:,:,Frame,:),[],C_Dim);
                                else
                                    DataRegionMask=DataRegion(:,:,Frame,Channel);
                                end
                            case 'YXCT'
                                if T_Projection&&MergeChannel
                                    DataRegionMask=max(max(DataRegion,[],T_Dim),[],C_Dim);
                                elseif T_Projection&&~MergeChannel
                                    DataRegionMask=max(DataRegion(:,:,Channel,:),[],T_Dim);
                                elseif ~T_Projection&&MergeChannel
                                    DataRegionMask=max(DataRegion(:,:,:,Frame),[],C_Dim);
                                else
                                    DataRegionMask=DataRegion(:,:,Channel,Frame);
                                end
                            case 'YXZC'
                                if Z_Projection&&MergeChannel
                                    DataRegionMask=max(max(DataRegion,[],Z_Dim),[],C_Dim);
                                elseif Z_Projection&&~MergeChannel
                                    DataRegionMask=max(DataRegion(:,:,:,Channel),[],Z_Dim);
                                elseif ~Z_Projection&&MergeChannel
                                    DataRegionMask=max(DataRegion(:,:,Slice,:),[],C_Dim);
                                else
                                    DataRegionMask=DataRegion(:,:,Slice,Channel);
                                end
                            case 'YXCZ'
                                if Z_Projection&&MergeChannel
                                    DataRegionMask=max(max(DataRegion,[],Z_Dim),[],C_Dim);
                                elseif Z_Projection&&~MergeChannel
                                    DataRegionMask=max(DataRegion(:,:,Channel,:),[],Z_Dim);
                                elseif ~Z_Projection&&MergeChannel
                                    DataRegionMask=max(DataRegion(:,:,:,Slice),[],C_Dim);
                                else
                                    DataRegionMask=DataRegion(:,:,Channel,Slice);
                                end
                            case 'YXZTC'
                                if Z_Projection&&~T_Projection&&MergeChannel
                                    DataRegionMask=max(max(DataRegion(:,:,:,Frame,:),[],Z_Dim),[],C_Dim);
                                elseif Z_Projection&&~T_Projection&&~MergeChannel
                                    DataRegionMask=max(DataRegion(:,:,:,Frame,Channel),[],Z_Dim);
                                elseif ~Z_Projection&&T_Projection&&MergeChannel
                                    DataRegionMask=max(max(DataRegion(:,:,Slice,:,:),[],T_Dim),[],C_Dim);
                                elseif ~Z_Projection&&T_Projection&&~MergeChannel
                                    DataRegionMask=max(DataRegion(:,:,Slice,:,Channel),[],T_Dim);
                                elseif ~Z_Projection&&~T_Projection&&MergeChannel
                                    DataRegionMask=max(DataRegion(:,:,Slice,Frame,:),[],C_Dim);
                                else
                                    DataRegionMask=DataRegion(:,:,Slice,Frame,Channel);
                                end
                            case 'YXTZC'
                                if Z_Projection&&~T_Projection&&MergeChannel
                                    DataRegionMask=max(max(DataRegion(:,:,Frame,:,:),[],Z_Dim),[],C_Dim);
                                elseif Z_Projection&&~T_Projection&&~MergeChannel
                                    DataRegionMask=max(DataRegion(:,:,Frame,:,Channel),[],Z_Dim);
                                elseif ~Z_Projection&&T_Projection&&MergeChannel
                                    DataRegionMask=max(max(DataRegion(:,:,:,Slice,:),[],T_Dim),[],C_Dim);
                                elseif ~Z_Projection&&T_Projection&&~MergeChannel
                                    DataRegionMask=max(DataRegion(:,:,Frame,:,Channel),[],T_Dim);
                                elseif ~Z_Projection&&~T_Projection&&MergeChannel
                                    DataRegionMask=max(DataRegion(:,:,Frame,Slice,:),[],C_Dim);
                                else
                                    DataRegionMask=DataRegion(:,:,Frame,Slice,Channel);
                                end
                            case 'YX[RGB]T'
                                DataRegionMask=DataRegion(:,:,:,Frame);
                            case 'YXT[RGB]'
                                DataRegionMask=DataRegion(:,:,Frame,:);
                        end
                    else
                        DataRegionMask=DataRegion;
                    end
                end
                if ~RGBOn
                    [CurrentImage]=Stack_Viewer_Adjust_Contrast_and_Color(CurrentImage,...
                        Channel_Info(Channel).ColorMap,...
                        Channel_Info(Channel).ContrastLow,...
                        Channel_Info(Channel).ContrastHigh,...
                        Channel_Info(Channel).ValueAdjust,...
                        Channel_Info(Channel).ColorScalar);
                    RGBOn=1;
                end
                CurrentImage=Stack_Viewer_ColorMasking(CurrentImage,squeeze(~DataRegionMask),DataRegionMaskColor);
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function Output_Image_RGB=Stack_Viewer_ColorMasking(Input_Image_RGB,Mask,OverlayColor)
            if size(Input_Image_RGB,1)~=size(Mask,1)||size(Input_Image_RGB,2)~=size(Mask,2)
                warning(['Input Height = ',num2str(size(Input_Image_RGB,1))])
                warning(['Mask Height = ',num2str(size(Mask,1))])
                warning(['Input Width = ',num2str(size(Input_Image_RGB,2))])
                warning(['Mask Width = ',num2str(size(Mask,2))])
                error('Size Mismatch!')
            end
            if size(Input_Image_RGB,3)~=3
                error('Must provide an RGB Image!')
            end
            try
                Mask=logical(Mask);
                Input_Image_R=Input_Image_RGB(:,:,1);
                Input_Image_G=Input_Image_RGB(:,:,2);
                Input_Image_B=Input_Image_RGB(:,:,3);

                Input_Image_R(Mask)=OverlayColor(1);
                Input_Image_G(Mask)=OverlayColor(2);
                Input_Image_B(Mask)=OverlayColor(3);

                Output_Image_RGB=cat(3,Input_Image_R,cat(3,Input_Image_G,Input_Image_B));
            catch
                warning('Memory issue Trying Again...')
                Input_Image_RGB=single(Input_Image_RGB);
                Input_Image_R=Input_Image_RGB(:,:,1);
                Input_Image_G=Input_Image_RGB(:,:,2);
                Input_Image_B=Input_Image_RGB(:,:,3);

                Input_Image_R(Mask)=OverlayColor(1);
                Input_Image_G(Mask)=OverlayColor(2);
                Input_Image_B(Mask)=OverlayColor(3);

                Output_Image_RGB=cat(3,Input_Image_R,cat(3,Input_Image_G,Input_Image_B));
                %Output_Image_RGB=double(Output_Image_RGB);
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function Output_Image_RGB=Stack_Viewer_ColorBarEmbedding(Input_Image_RGB,ColorBarOverlay,Channel)
            Output_Image_RGB=Input_Image_RGB;
            if Channel>0
                [   TempColorMap,...
                    ~,...
                    ~,...
                    ~]=...
                    StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                        [0,ColorBarOverlay.NumColors],1);
                switch ColorBarOverlay.Orientation
                    case 'Horizontal'
                        for y=1:length(ColorBarOverlay.YData)
                            Output_Image_RGB(ColorBarOverlay.YData(y),ColorBarOverlay.XData,:)=TempColorMap;
                        end
                    case 'Vertical'
                        for x=1:length(ColorBarOverlay.XData)
                            Output_Image_RGB(ColorBarOverlay.YData,ColorBarOverlay.XData(x),:)=flipud(TempColorMap);
                        end
                end
            end
        end
        function Colorbar_Image_RGB=Stack_Viewer_ColorBarImage(ColorBarOverlay,Channel)
            Colorbar_Image_RGB=zeros(length(ColorBarOverlay.YData),length(ColorBarOverlay.XData),3);
            if Channel>0
                [   TempColorMap,...
                    ~,...
                    ~,...
                    ~]=...
                    StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                        [0,ColorBarOverlay.NumColors],1);
                switch ColorBarOverlay.Orientation
                    case 'Horizontal'
                        for y=1:length(ColorBarOverlay.YData)
                            Colorbar_Image_RGB((y),1:length(ColorBarOverlay.XData),:)=TempColorMap;
                        end
                    case 'Vertical'
                        for x=1:length(ColorBarOverlay.XData)
                            Colorbar_Image_RGB(1:length(ColorBarOverlay.YData),(x),:)=flipud(TempColorMap);
                        end
                end
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function RefreshViewer(~,~,~)
            figure(ViewerFig)
            AllCurrentAxes=findall(ViewerFig,'Type','axes');
            %AllCurrentAxes=imhandles(ViewerFig);
            %AllCurrentAxes=imgca(ViewerFig);
            %warning([num2str(length(AllCurrentAxes))])
            for a=1:length(AllCurrentAxes)
                Good2Delete=1;
                if AllCurrentAxes(a)==ViewerImageAxis
                    Good2Delete=0;
                end
                if AllCurrentAxes(a)==ColorBarAxis
                    Good2Delete=0;
                end
                if T_Stack
                    if AllCurrentAxes(a)==TracePlotAxis
                        Good2Delete=0;
                    end
                end
                if AllCurrentAxes(a)==HistAxis
                    Good2Delete=0;
                end
                for i=1:length(TileAxes)
                    if AllCurrentAxes(a)==TileAxes{i}
                        Good2Delete=0;
                    end
                end
                for i=1:length(MaskAxes)
                    if AllCurrentAxes(a)==MaskAxes{i}
                        Good2Delete=0;
                    end
                end
                if Good2Delete
                    %warning('Deleting')
                    cla(AllCurrentAxes(a))
                    delete(AllCurrentAxes(a));
                end
            end
            set(ExportMovieButton, 'Enable', 'on');    
            set(ExportImageButton, 'Enable', 'on');
            if T_Stack
                set(ExportTraceButton, 'Enable', 'on');   
                set(TraceScaleButton, 'Enable', 'on');
                set(UpdateTrace_Pixel_Button, 'Enable', 'on');
                set(UpdateTrace_ROI_Button, 'Enable', 'on');
                set(UndoROI_Button, 'Enable', 'on');
            end
            set(ExportDataButton, 'Enable', 'on');    
            set(ScaleBarButton, 'Enable', 'on');
            set(ImageLabelButton, 'Enable', 'on');
            set(ColorBarOverlayButton, 'Enable', 'on');
            set(ZoomInButton, 'Enable', 'on');
            set(ZoomResetButton, 'Enable', 'on');
            set(PlayMovieButton, 'Enable', 'on');
            set(AddLocalizationButton, 'Enable', 'on');
            set(DeleteLocalizationButton, 'Enable', 'on');
            set(UndoLocalizationButton, 'Enable', 'on');
            set(LocalizationTypeList, 'Enable', 'on');
            set(DisplayLocalizationButton, 'Enable', 'on');
            set(FormatLocalizationMarkersButton, 'Enable', 'on');

        end
        function [BufferImageAxes,BufferMaskAxes,BufferTileAxes]=...
                ClearImageDisplay(Channel,Frame,Slice,ImageFig,BufferImageAxes,BufferMaskAxes,BufferTileAxes)
            figure(ImageFig)
            for i=1:length(BufferImageAxes)
                if isvalid(BufferImageAxes{i})
                    if ~any(BufferImageAxes{i}==ViewerImageAxis)
                        %warning('Deleting')
                        delete(BufferImageAxes{i})
                    end
                end
            end
            for i=1:length(BufferTileAxes)
                if isvalid(BufferTileAxes{i})
                    if ~any(BufferTileAxes{i}==TileAxes)
                        %warning('Deleting')
                        delete(BufferTileAxes{i})
                    end
                end
            end
            if MaskOn
                for i=1:length(BufferMaskAxes)
                    if isvalid(BufferMaskAxes{i})
                        if ~any(BufferMaskAxes{i}==MaskAxes)
                            %warning('Deleting')
                            delete(BufferMaskAxes{i})
                        end
                    end
                end
            end
            BufferImageAxes=[];
            BufferMaskAxes=[];
            BufferTileAxes=[];
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function [ImageFig,ImageAxis,ImageAxisPos,MaskAxes,TileAxes]=...
                ImageDisplay(Channel,Frame,Slice,CurrentImages,ImageFig,ImageAxis,ImageAxisPos,MaskAxes,TileAxes,FigSize)
            figure(ImageFig)
            if ~isempty(ImageAxis)
                if isvalid(ImageAxis)
                    if ImageFig==ViewerFig
                        if TileChannels||TileSlices||TileFrames
                            set(ImageAxis,'visible','off')
%                         else
%                             axes(ImageAxis)
%                             cla(ImageAxis)
                        end
                        axes(ImageAxis)
                        cla(ImageAxis)
                    end
                end
%             else
%                 ImageAxis=subplot(100,100,1);
%                 set(ImageAxis,'position',ImageAxisPos);
%                 axis off
            end
            %if ~isempty(TileAxes)
                for i=1:length(TileAxes)
                    %if isvalid(TileAxes{i})
                        %set(TileAxes{i},'visible','off')
                        delete(TileAxes{i})
                   %end
                end
                %TileAxes=[];
            %end
            if MaskOn
                if ~isempty(MaskAxes)
                    if isfield(MaskAxes,'ForegroundAxis')
                        MaskAxes=rmfield(MaskAxes,'ForegroundAxis');
                    end
                    for i=1:length(MaskAxes)
                        %if isvalid(MaskAxes{i})
                            delete(MaskAxes{i})
                        %end
                    end
                end
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            for i=1:length(CurrentImages)
                if TileChannels||TileSlices||TileFrames
                    TileAxes{i}=axes('position',TileSettings.Tiles(i).Pos);
                    %set(TileAxes{i},'position',TileSettings.Tiles(i).Pos);
                end
                if ~CurrentImages(i).MaskOn
                    if ~CurrentImages(i).RGB_Stack&&~CurrentImages(i).RGBOn
                        imagesc(CurrentImages(i).CurrentImage);
                        axis equal tight
                        hold on
                        if TileChannels||TileSlices||TileFrames
                            if CurrentImages(i).Z_Projection&&~CurrentImages(i).T_Projection
                                colormap(TileAxes{i},Channel_Info(CurrentImages(i).Channel).Z_Projection_Data.ColorMaps.ColorMap);
                                caxis(Channel_Info(CurrentImages(i).Channel).Z_Projection_Data.Display_Limits);
                            elseif ~CurrentImages(i).Z_Projection&&CurrentImages(i).T_Projection
                                colormap(TileAxes{i},Channel_Info(CurrentImages(i).Channel).T_Projection_Data.ColorMaps.ColorMap);
                                caxis(Channel_Info(CurrentImages(i).Channel).T_Projection_Data.Display_Limits);
                            else
                                colormap(TileAxes{i},Channel_Info(CurrentImages(i).Channel).ColorMap);
                                caxis(Channel_Info(CurrentImages(i).Channel).Display_Limits);
                            end
                        else
                            if CurrentImages(i).Z_Projection&&~CurrentImages(i).T_Projection
                                colormap(ImageAxis,Channel_Info(CurrentImages(i).Channel).Z_Projection_Data.ColorMaps.ColorMap);
                                caxis(Channel_Info(CurrentImages(i).Channel).Z_Projection_Data.Display_Limits);
                            elseif ~CurrentImages(i).Z_Projection&&CurrentImages(i).T_Projection
                                colormap(ImageAxis,Channel_Info(CurrentImages(i).Channel).T_Projection_Data.ColorMaps.ColorMap);
                                caxis(Channel_Info(CurrentImages(i).Channel).T_Projection_Data.Display_Limits);
                            else
                                colormap(ImageAxis,Channel_Info(CurrentImages(i).Channel).ColorMap);
                                caxis(Channel_Info(CurrentImages(i).Channel).Display_Limits);
                            end
                        end
                    elseif CurrentImages(i).RGBOn
                        imshow(double(CurrentImages(i).CurrentImage),[],'border','tight');
                    else
                        error('Unable to display!')
                    end
                else
                    if ~CurrentImages(i).RGB_Stack&&~CurrentImages(i).RGBOn
                        % Background image
                        imagesc(CurrentImages(i).CurrentImage);
                        if TileChannels||TileSlices||TileFrames
                            colormap(TileAxes{i},Channel_Info(CurrentImages(i).Channel).ColorMap);
                        else
                            colormap(ImageAxis,Channel_Info(CurrentImages(i).Channel).ColorMap);
                        end
                        axis equal tight
                        caxis(Channel_Info(CurrentImages(i).Channel).Display_Limits);
                        if ZoomOn
                            xlim([ZoomDataRegion_Props.BoundingBox(1),ZoomDataRegion_Props.BoundingBox(1)+ZoomDataRegion_Props.BoundingBox(3)+1])
                            ylim([ZoomDataRegion_Props.BoundingBox(2),ZoomDataRegion_Props.BoundingBox(2)+ZoomDataRegion_Props.BoundingBox(4)+1])
                        else
                            xlim([0.5,ImageWidth+0.5])
                            ylim([0.5,ImageHeight+0.5])
                        end
                        % Mask Overlay
                        if TileChannels||TileSlices||TileFrames
                            MaskAxes{i}=axes('position',TileSettings.Tiles(i).Pos);
                        else
                            MaskAxes{i}=axes('position',ImageAxisPos);
                        end
                        if isfield(MaskAxes,'ForegroundAxis')
                            MaskAxes=rmfield(MaskAxes,'ForegroundAxis');
                        end
                        ThreshMask=CurrentImages(i).CurrentImage;
                        ThreshMask(isnan(ThreshMask))=0;
                        ThreshMask(ThreshMask<=Channel_Info(CurrentImages(i).Channel).MaskLim)=0;
                        ThreshMask(ThreshMask>Channel_Info(CurrentImages(i).Channel).MaskLim)=1;
                        if Channel_Info(CurrentImages(i).Channel).MaskInvert
                            ThreshMask=~ThreshMask;
                        end
                        imagesc(ThreshMask,'alphadata',Channel_Info(CurrentImages(i).Channel).MaskAlpha);
                        axis equal tight
                        set(MaskAxes{i},'color','none','visible','off')
                        colormap(MaskAxes{i},Channel_Info(CurrentImages(i).Channel).MaskColorMap);
                        %linkaxes([ImageAxis MaskAxes{i}])
                        if ZoomOn
                            xlim([ZoomDataRegion_Props.BoundingBox(1),ZoomDataRegion_Props.BoundingBox(1)+ZoomDataRegion_Props.BoundingBox(3)+1])
                            ylim([ZoomDataRegion_Props.BoundingBox(2),ZoomDataRegion_Props.BoundingBox(2)+ZoomDataRegion_Props.BoundingBox(4)+1])
                        else
                            xlim([0.5,ImageWidth+0.5])
                            ylim([0.5,ImageHeight+0.5])
                        end
                    else
                        warning('RGB Mask Overlay not currently working correctly...')
                        imshow(double(CurrentImages(i).CurrentImage),[],'border','tight');
%                         ThreshMask=CurrentImages(i).CurrentImage;
%                         ThreshMask(isnan(ThreshMask))=0;
%                         ThreshMask(ThreshMask<=Channel_Info(Channel).MaskLim)=0;
%                         ThreshMask(ThreshMask>Channel_Info(Channel).MaskLim)=1;
%                         if MaskInvert
%                             ThreshMask=~ThreshMask;
%                         end
%                         MaskColorMap= vertcat(ColorDefinitionsLookup(MaskColor),[0,0,0]);
%                         %ThreshMaskColor = grs2rgb(ThreshMask,MaskColorMap);
%                         [ThreshMaskColor]=...
%                             Stack_Viewer_Adjust_Contrast_and_Color(ThreshMask,MaskColorMap,0,1,0,1);
%                         if TileChannels||TileSlices||TileFrames
%                             MaskAxes{i}=axes('position',TileSettings.Tiles(i).Pos);
%                         else
%                             MaskAxes{i}=axes('position',ImageAxisPos);
%                         end
%                         MaskLayer(i)=imshow(ThreshMaskColor,[]);
%                         alpha(MaskLayer(i),MaskAlpha)
%                         if TileChannels||TileSlices||TileFrames
%                             MaskAxes(i).ForegroundAxis=axes('position',TileSettings.Tiles(i).Pos);
%                         else
%                             MaskAxes(i).ForegroundAxis=axes('position',ImageAxisPos);
%                         end
%                         TempImageRGB=[];
%                         for rgb=1:3
%                             TempImage=CurrentImages(i).CurrentImage(:,:,rgb);
%                             size(TempImage)
%                             size(ThreshMask)
%                             TempImage(~ThreshMask)=NaN;
%                             TempImageRGB(:,:,rgb)=TempImage;
%                         end
%                         ForegroundLayer(i)=imshow(TempImageRGB,[]);
%                         alpha(ForegroundLayer(i),MaskAlpha)
                        if ZoomOn
                            xlim([ZoomDataRegion_Props.BoundingBox(1),ZoomDataRegion_Props.BoundingBox(1)+ZoomDataRegion_Props.BoundingBox(3)+1])
                            ylim([ZoomDataRegion_Props.BoundingBox(2),ZoomDataRegion_Props.BoundingBox(2)+ZoomDataRegion_Props.BoundingBox(4)+1])
                        else
                            xlim([0.5,ImageWidth+0.5])
                            ylim([0.5,ImageHeight+0.5])
                        end
                        %figure, imshow(ThreshMaskColor,[])
                    end            
                end
                if DataRegionBorderOn
                    hold on
                    if ~isempty(DataRegionBorderLine)
                        for j=1:length(DataRegionBorderLine)
                            plot(DataRegionBorderLine{j}.BorderLine(:,2),...
                                DataRegionBorderLine{j}.BorderLine(:,1),...
                                BorderLineStyle,'color',BorderColor,'linewidth',BorderWidth)
                        end
                    end
                end
                if DisplayEditsOn&&~isempty(EditRecord)
                    for e=1:length(EditRecord)
                        if CurrentImages(i).Channel==EditRecord(e).Channel&&...
                            CurrentImages(i).Frame==EditRecord(e).Frame&&...
                            CurrentImages(i).Slice==EditRecord(e).Slice
                            for j=1:length(EditRecord(e).EditRegionBorderLine)
                                plot(EditRecord(e).EditRegionBorderLine{j}.BorderLine(:,2),...
                                    EditRecord(e).EditRegionBorderLine{j}.BorderLine(:,1),...
                                    EditsBorderLineStyle,'color',EditsBorderColor,'linewidth',EditsBorderWidth)
                            end
                        end
                    end
                end
                if ~isempty(ROIs)&&ROIBorders
                    hold on
                    for ROI=1:length(ROIs)
                        if CurrentImages(i).Z_Projection||CurrentImages(i).Slice==0||CurrentImages(i).Slice==ROIs(ROI).Slice%&&Channel==ROIs(NumROIs).Channel
                            if ROIs(ROI).Type==1
                                %plot(ROIs(ROI).Coord(1),ROIs(ROI).Coord(2),PixelTraceMarker,'color',ROIs(ROI).Color,'markersize',PixelTraceThreshMarkersize)
                                th = 0:pi/50:2*pi;
                                xunit = ROI_Marker_Radius_px * cos(th) + ROIs(ROI).Coord(1);
                                yunit = ROI_Marker_Radius_px * sin(th) + ROIs(ROI).Coord(2);
                                plot(xunit, yunit,ROI_Border_LineStyle,'color','w','LineWidth',ROI_Border_LineWidth+1);
                                plot(xunit, yunit,ROI_Border_LineStyle,'color',ROIs(ROI).Color,'LineWidth',ROI_Border_LineWidth);
                            else
                                for j=1:length(ROIs(ROI).BorderLine)
                                    plot(ROIs(ROI).BorderLine{j}.BorderLine(:,2),...
                                        ROIs(ROI).BorderLine{j}.BorderLine(:,1),...
                                        ROI_Border_LineStyle,'color','w','linewidth',ROI_Border_LineWidth+1)
                                    plot(ROIs(ROI).BorderLine{j}.BorderLine(:,2),...
                                        ROIs(ROI).BorderLine{j}.BorderLine(:,1),...
                                        ROI_Border_LineStyle,'color',ROIs(ROI).Color,'linewidth',ROI_Border_LineWidth)
                                end
                            end
                        end
                    end
                end            
                if ScaleBarOn
                    if ZoomOn
                        if isempty(ZoomScaleBar)
                            set(ScaleBarButton,'value',1)
                            AddScaleBar;
                        end
                        hold on
                        plot(ZoomScaleBar.XData,ZoomScaleBar.YData,'-','color',ZoomScaleBar.LineColor,'linewidth',ZoomScaleBar.LineWidth)
                        TempUnit=ZoomScaleBar.Unit;
                        if strcmp(TempUnit,'um')&&ForceGreekCharacter
                            TempUnit='\mum';
                        end
                        if ZoomScaleBar.TextOn
                            if any(ZoomScaleBar.Position=='B')
                                text((ZoomScaleBar.XData(2)-ZoomScaleBar.XData(1))/2+ZoomScaleBar.XData(1),...
                                    ZoomScaleBar.YData(1)-ZoomDataRegion_Props.BoundingBox(4)*ZoomScaleBar.VertCornerAdjust,...
                                    [num2str(ZoomScaleBar.Length),' ',TempUnit],'color',ZoomScaleBar.LineColor,...
                                    'fontname','arial','fontsize',ZoomScaleBar.FontSize,'HorizontalAlignment','center','VerticalAlignment','middle');
                            else
                                text((ZoomScaleBar.XData(2)-ZoomScaleBar.XData(1))/2+ZoomScaleBar.XData(1),...
                                    ZoomScaleBar.YData(1)+ZoomDataRegion_Props.BoundingBox(4)*ZoomScaleBar.VertCornerAdjust,...
                                    [num2str(ZoomScaleBar.Length),' ',TempUnit],'color',ZoomScaleBar.LineColor,...
                                    'fontname','arial','fontsize',ZoomScaleBar.FontSize,'HorizontalAlignment','center','VerticalAlignment','middle');
                            end
                        end
                    else
                        if isempty(ScaleBar)
                            AddScaleBar
                        end
                        if exist('ScaleBarButton')
                            set(ScaleBarButton,'value',1)
                        end
                        hold on
                        plot(ScaleBar.XData,ScaleBar.YData,'-','color',ScaleBar.LineColor,'linewidth',ScaleBar.LineWidth)
                        TempUnit=ScaleBar.Unit;
                        if strcmp(TempUnit,'um')&&ForceGreekCharacter
                            TempUnit='\mum';
                        end
                        if ScaleBar.TextOn
                            if any(ScaleBar.Position=='B')
                                text((ScaleBar.XData(2)-ScaleBar.XData(1))/2+ScaleBar.XData(1),...
                                    ScaleBar.YData(1)-ScaleBar.YData(1)*ScaleBar.VertCornerAdjust,...
                                    [num2str(ScaleBar.Length),' ',TempUnit],'color',ScaleBar.LineColor,...
                                    'fontname','arial','fontsize',ScaleBar.FontSize,'HorizontalAlignment','center','VerticalAlignment','middle');
                            else
                                text((ScaleBar.XData(2)-ScaleBar.XData(1))/2+ScaleBar.XData(1),...
                                    ScaleBar.YData(1)+ScaleBar.YData(1)*ScaleBar.VertCornerAdjust,...
                                    [num2str(ScaleBar.Length),' ',TempUnit],'color',ScaleBar.LineColor,...
                                    'fontname','arial','fontsize',ScaleBar.FontSize,'HorizontalAlignment','center','VerticalAlignment','middle');
                            end
                        end
                    end
                end
                if ColorBarOverlayOn==2&&~CurrentImages(i).MergeChannel
                    Colorbar_Image_RGB=Stack_Viewer_ColorBarImage(ColorBarOverlay,CurrentImages(i).Channel);
                    hold on
                    CBI=imshow(Colorbar_Image_RGB,...
                        'XData',[ColorBarOverlay.XData(1),ColorBarOverlay.XData(length(ColorBarOverlay.XData))],...
                        'YData',[ColorBarOverlay.YData(1),ColorBarOverlay.YData(length(ColorBarOverlay.YData))]);
                end
                if ColorBarOverlayOn&&~CurrentImages(i).MergeChannel
                    hold on
                    for CB=1:length(ColorBarOverlay.Border)
                        CBP(CB)=plot(ColorBarOverlay.Border(CB).XData,ColorBarOverlay.Border(CB).YData,...
                            '-','color',ColorBarOverlay.Color,'linewidth',ColorBarOverlay.LineWidth);
                    end
                    hold on
                    CBT(1)=text(ColorBarOverlay.LowText_XData,ColorBarOverlay.LowText_YData,...
                        [ColorBarOverlay.LowText_Pre,num2str(Channel_Info(CurrentImages(i).Channel).Display_Limits(1)),ColorBarOverlay.LowText_Post],...
                        'color',ColorBarOverlay.Color,'fontsize',ColorBarOverlay.FontSize,'fontname','arial',...
                        'horizontalalignment',ColorBarOverlay.LowText_HorzAlign,...
                        'verticalalignment',ColorBarOverlay.LowText_VertAlign);
                    hold on
                    CBT(2)=text(ColorBarOverlay.HighText_XData,ColorBarOverlay.HighText_YData,...
                        [ColorBarOverlay.HighText_Pre,num2str(Channel_Info(CurrentImages(i).Channel).Display_Limits(2)),ColorBarOverlay.HighText_Post],...
                        'color',ColorBarOverlay.Color,'fontsize',ColorBarOverlay.FontSize,'fontname','arial',...
                        'horizontalalignment',ColorBarOverlay.HighText_HorzAlign,...
                        'verticalalignment',ColorBarOverlay.HighText_VertAlign);
                end
                if ~isempty(LocalizationMarkers)&&LocalizationMarkersOn
                    hold on
                    for l=1:length(LocalizationMarkers)
                        for ll=1:length(LocalizationMarkers(l).Markers)
                            if      (CurrentImages(i).Z_Projection||CurrentImages(i).Slice==0||...
                                    CurrentImages(i).Slice==LocalizationMarkers(l).Markers(ll).Z)&&...
                                    (CurrentImages(i).T_Projection||CurrentImages(i).Frame==0||...
                                    any(CurrentImages(i).Frame==[LocalizationMarkers(l).Markers(ll).T-LocalizationMarkers(l).LabelPersistence.PreFrames:...
                                    LocalizationMarkers(l).Markers(ll).T+LocalizationMarkers(l).LabelPersistence.PreFrames]))
                                if LocalizationMarkers(l).Style==1
                                    plot(LocalizationMarkers(l).Markers(ll).X,...
                                        LocalizationMarkers(l).Markers(ll).Y,...
                                        LocalizationMarkers(l).LineMarkerStyle,...
                                        'color',LocalizationMarkers(l).Color,...
                                        'markersize',LocalizationMarkers(l).MarkerSize)
                                elseif LocalizationMarkers(l).Style==2
                                    th = 0:pi/50:2*pi;
                                    xunit = LocalizationMarkers(l).Radius_px * cos(th) + LocalizationMarkers(l).Markers(ll).X;
                                    yunit = LocalizationMarkers(l).Radius_px * sin(th) + LocalizationMarkers(l).Markers(ll).Y;
                                    plot(xunit, yunit,LocalizationMarkers(l).LineMarkerStyle,'color','w','LineWidth',LocalizationMarkers(l).LineWidth);
                                    plot(xunit, yunit,LocalizationMarkers(l).LineMarkerStyle,'color',LocalizationMarkers(l).Color,...
                                        'LineWidth',LocalizationMarkers(l).LineWidth);
                                end
                                if LocalizationMarkers(l).MarkerTextOn
                                    text(...
                                        LocalizationMarkers(l).Markers(ll).X+LocalizationMarkers(i).TextXOffset,...
                                        LocalizationMarkers(l).Markers(ll).Y+LocalizationMarkers(i).TextYOffset,...
                                        [LocalizationMarkers(l).Labels,num2str(ll)],...
                                        'color',LocalizationMarkers(l).Color,...
                                        'fontsize',LocalizationMarkers(l).FontSize,...
                                        'horizontalalignment',LocalizationMarkers(l).HorizontalAlignment,...
                                        'verticalalignment',LocalizationMarkers(l).VerticalAlignment);
                                end
                            end
                        end
                    end
                end
                if ZoomOn
                    xlim([ZoomDataRegion_Props.BoundingBox(1),ZoomDataRegion_Props.BoundingBox(1)+ZoomDataRegion_Props.BoundingBox(3)+1])
                    ylim([ZoomDataRegion_Props.BoundingBox(2),ZoomDataRegion_Props.BoundingBox(2)+ZoomDataRegion_Props.BoundingBox(4)+1])
                else
                    xlim([0.5,ImageWidth+0.5])
                    ylim([0.5,ImageHeight+0.5])
                end
                if ImageLabelOn
                    TempColor='w';
                    if ~CurrentImages(i).MergeChannel
                        if ischar(Channel_Info(CurrentImages(i).Channel).DisplayColorMap)
                            if length(Channel_Info(CurrentImages(i).Channel).DisplayColorMap)==1
                                TempColor=Channel_Info(CurrentImages(i).Channel).DisplayColorMap;
                            else
                                TempColor='w';
                            end
                        else
                            TempColor=Channel_Info(CurrentImages(i).Channel).DisplayColorMap;
                        end
                    end
                    TempC=CurrentImages(i).Channel;
                    TempZ=CurrentImages(i).Slice;
                    TempT=CurrentImages(i).Frame;
                    if CurrentImages(i).MergeChannel
                        TempC=0;
                    end
                    if CurrentImages(i).Z_Projection
                        TempZ=0;
                        if CurrentImages(i).MergeChannel
                            TempC=-1;
                        end
                    end
                    if CurrentImages(i).T_Projection
                        TempT=0;
                        if CurrentImages(i).MergeChannel
                            TempC=-2;
                        end
                    end
                    if ZoomOn
                        [~,CurrentLabel]=GetCurrentPosition(ImagingInfo,[],[],[],ZoomImageLabel,TempC,1,TempZ,1,TempT,1);
                    else
                        [~,CurrentLabel]=GetCurrentPosition(ImagingInfo,[],[],[],ImageLabel,TempC,1,TempZ,1,TempT,1);
                    end
                    FinalLabel{1}=CurrentLabel;
                    for fm=1:length(FrameMarkers)
                        for j=1:length(FrameMarkers(fm).Frames)
                            if iscell(FrameMarkers(fm).Frames)
                                TempFrames=FrameMarkers(fm).Frames{j};
                            else
                                TempFrames=FrameMarkers(fm).Frames(j);
                            end
                            if isfield(FrameMarkers,'LabelPersistence')
                                if FrameMarkers(fm).LabelPersistence.PreFrames>0&&FrameMarkers(fm).LabelPersistence.PostFrames>0
                                    TempFrames=[TempFrames-FrameMarkers(fm).LabelPersistence.PreFrames:TempFrames+FrameMarkers(fm).LabelPersistence.PostFrames];
                                elseif FrameMarkers(fm).LabelPersistence.PreFrames<=0&&FrameMarkers(fm).LabelPersistence.PostFrames>0
                                    TempFrames=[TempFrames:TempFrames+FrameMarkers(fm).LabelPersistence.PostFrames];
                                elseif FrameMarkers(fm).LabelPersistence.PreFrames>0&&FrameMarkers(fm).LabelPersistence.PostFrames<=0
                                    TempFrames=[TempFrames-FrameMarkers(fm).LabelPersistence.PreFrames:TempFrames];
                                end
                            end
                            if FrameMarkers(fm).MarkerOn&&FrameMarkerLabelsOn&&any(CurrentImages(i).Frame==TempFrames)
                                if ~isempty(FrameMarkers(fm).Labels{j})
                                    FinalLabel=vertcat(FinalLabel,FrameMarkers(fm).Labels{j});
                                end
                            end
                        end
                    end
                    if ZoomOn
                        text(ZoomImageLabel.XData,ZoomImageLabel.YData,FinalLabel,...
                            'color',TempColor,'fontname','arial','fontsize',ZoomImageLabel.FontSize,...
                            'horizontalalignment',ZoomImageLabel.HorizontalAlignment,...
                            'verticalalignment',ZoomImageLabel.VerticalAlignment);
                    else
                        text(ImageLabel.XData,ImageLabel.YData,FinalLabel,...
                            'color',TempColor,'fontname','arial','fontsize',ImageLabel.FontSize,...
                            'horizontalalignment',ImageLabel.HorizontalAlignment,...
                            'verticalalignment',ImageLabel.VerticalAlignment);
                    end
                end
                if TileChannels||TileSlices||TileFrames
                    set(TileAxes{i},'XTick', []);
                    set(TileAxes{i},'YTick', []);
                    set(TileAxes{i},'position',TileSettings.Tiles(i).Pos);
                else
                    set(ImageAxis,'XTick', []);
                    set(ImageAxis,'YTick', []);
                    set(ImageAxis,'units','normalized','position',ImageAxisPos)
                end
            end
            if ImageFig==ViewerFig
                drawnow;
                if TileChannels
                    set(ImageFig,'name',[SaveName,' Frame ',num2str(CurrentImages(i).Frame),' Slice ',num2str(CurrentImages(i).Slice),' Tiled Channels']);
                elseif TileSlices
                    set(ImageFig,'name',[SaveName,' Frame ',num2str(CurrentImages(i).Frame),' Tiled Slices ',Channel_Labels{CurrentImages(i).Channel}]);
                elseif TileFrames
                    set(ImageFig,'name',[SaveName,' Tiled Frames Slice ',num2str(CurrentImages(i).Slice),' ',Channel_Labels{CurrentImages(i).Channel}]);
                else
                    if MergeChannel
                        set(ImageFig,'name',[SaveName,' Frame ',num2str(CurrentImages(i).Frame),' Slice ',num2str(CurrentImages(i).Slice),' MERGED Channels ',num2str(Channels2Merge)]);
                    else
                        set(ImageFig,'name',[SaveName,' Frame ',num2str(CurrentImages(i).Frame),' Slice ',num2str(CurrentImages(i).Slice),' ',Channel_Labels{CurrentImages(i).Channel}]);
                    end
                end
                if ~RGB_Stack&&T_Stack
                    try
                        [CurrentFrameMarker]=PlotCurrentFrameMarker(Frame,CurrentFrameMarker,TracePlotAxis);
                    catch
                        warning('Problem updating trace')
                    end
                    if LiveHist
                        HistDisplay(HistAxis,HistAxisPosition);
                    end
                end
            end
            if ~isempty(BufferViewerImageAxes)||~isempty(BufferMaskAxes)||~isempty(BufferTileAxes)
                [BufferViewerImageAxes,BufferMaskAxes,BufferTileAxes]=ClearImageDisplay(Channel,Frame,Slice,ViewerFig,BufferViewerImageAxes,BufferMaskAxes,BufferTileAxes);
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function MakeChannelEditable(~,~,~)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(MakeChannelEditableButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            Channel_Info(Channel).Editable=get(MakeChannelEditableButton,'value');
            if ~Channel_Info(Channel).Editable
                DisplayEditsOn=0;
                set(DisplayEditsButton,'value',DisplayEditsOn)
                set(EditDataButton,'Enable','off');
                set(UndoEditButton,'Enable','off');
                set(DisplayEditsButton,'Enable','off');
                set(DisplayEditsFormatButton,'Enable','off');
            else
                if ~EditWarning
                    warndlg({'You should use the edit data feature carefully and appropriately';...
                        'Editing should only be peformed on layers that include things like ';...
                        'adjusting masks to appropriately highlight features but not the primary';...
                        'imaging data or analysis layers to remove noise or false positive';...
                        'detection events as long as there is a strict exclusion policy in place';...
                        'NOTE that ALL edits are recorded and provided in the <EditRecord>';...
                        'structure upon completing of the analysis. This should always be retained';
                        'for your records or if asked to provide evidence for exclusions. The';...
                        '<EditRecord> structure also acts as an UNDO buffer for ALL EDITS.'},...
                        'Edit Mode Warning/Disclaimer');
                    DislaimerWarning = questdlg({'You should use the edit data feature carefully and appropriately';...
                        'Editing should only be peformed on layers that include things like ';...
                        'adjusting masks to appropriately highlight features but not the primary';...
                        'imaging data or analysis layers to remove noise or false positive';...
                        'detection events as long as there is a strict exclusion policy in place';...
                        'NOTE that ALL edits are recorded and provided in the <EditRecord>';...
                        'structure upon completing of the analysis. This should always be retained';
                        'for your records or if asked to provide evidence for exclusions. The';...
                        '<EditRecord> structure also acts as an UNDO buffer for ALL EDITS.'},...
                        'Edit Mode Warning/Disclaimer','Acknowledged','Acknowledged');
                end
                EditWarning=EditWarning+1;
                DisplayEditsOn=1;
                set(DisplayEditsButton,'value',DisplayEditsOn)
                set(EditDataButton,'Enable','on');
                if ~isempty(EditRecord)
                    set(UndoEditButton,'Enable','on');
                end
                set(DisplayEditsButton,'Enable','on');
                set(DisplayEditsFormatButton,'Enable','on');
            end            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(MakeChannelEditableButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        function [EditRegion,EditData,EditRegionBorderLine]=ApplyEdit(EditRegion,Channel,Frame,Slice,StackOrder,EditMode)
            TempData=FindCurrentImage(Channel,Frame,Slice,StackOrder,0,0,0,1,0,0,0,[]);
            EditData=TempData(1).CurrentImage;
            EditData(~EditRegion)=0;
            switch EditMode
                case 'ROI'
                    [EditRegionBorderLine]=FindROIBorders(EditRegion,1);
                case 'Area'
                    [EditRegionBorderLine]=FindROIBorders(EditRegion,1);
                case 'Image'
                    TempEditRegion=TempData(1).CurrentImage;
                    TempEditRegion(TempEditRegion>0)=1;
                    TempEditRegion(isnan(TempEditRegion))=0;
                    [EditRegionBorderLine]=FindROIBorders(logical(TempEditRegion),1);
            end
            clear TempData TempEditRegion
            switch StackOrder
                case 'YXT'
                    CurrentImage=ImageArray(:,:,Frame);
                case 'YXZ'
                    CurrentImage=ImageArray(:,:,Slice);
                case 'YXC'
                    CurrentImage=ImageArray(:,:,Channel);
                case 'YXZT'
                    CurrentImage=ImageArray(:,:,Slice,Frame);
                case 'YXTZ'
                    CurrentImage=ImageArray(:,:,Frame,Slice);
                case 'YXTC'
                    CurrentImage=ImageArray(:,:,Frame,Channel);
                case 'YXCT'
                    CurrentImage=ImageArray(:,:,Channel,Frame);
                case 'YXZC'
                    CurrentImage=ImageArray(:,:,Slice,Channel);
                case 'YXCZ'
                    CurrentImage=ImageArray(:,:,Channel,Slice);
                case 'YXZTC'
                    CurrentImage=ImageArray(:,:,Channel,Slice);
                case 'YXTZC'
                    CurrentImage=ImageArray(:,:,Channel,Slice);
                case 'YX[RGB]T'
                case 'YXT[RGB]'
            end
            CurrentImage=squeeze(CurrentImage);
            CurrentImage(EditRegion)=0;
            switch StackOrder
                case 'YXT'
                    if ~isempty(DataRegion)
                        if length(size(DataRegion))>2
                            CurrentImage(~DataRegion(:,:,Frame))=NaN;
                        else
                            CurrentImage(~DataRegion)=NaN;
                        end
                    end
                case 'YXZ'
                    if ~isempty(DataRegion)
                        if length(size(DataRegion))>2
                            CurrentImage(~DataRegion(:,:,Slice))=NaN;
                        else
                            CurrentImage(~DataRegion)=NaN;
                        end
                    end
                case 'YXC'
                    if ~isempty(DataRegion)
                        if length(size(DataRegion))>2
                            CurrentImage(~DataRegion(:,:,Channel))=NaN;
                        else
                            CurrentImage(~DataRegion)=NaN;
                        end
                    end
                case 'YXZT'
                    if ~isempty(DataRegion)
                        if length(size(DataRegion))>2
                            CurrentImage(~DataRegion(:,:,Slice,Frame))=NaN;
                        else
                            CurrentImage(~DataRegion)=NaN;
                        end
                    end
                case 'YXTZ'
                    if ~isempty(DataRegion)
                        if length(size(DataRegion))>2
                            CurrentImage(~DataRegion(:,:,Frame,Slice))=NaN;
                        else
                            CurrentImage(~DataRegion)=NaN;
                        end
                    end
                case 'YXTC'
                    if ~isempty(DataRegion)
                        if length(size(DataRegion))>2
                            CurrentImage(~DataRegion(:,:,Frame,Channel))=NaN;
                        else
                            CurrentImage(~DataRegion)=NaN;
                        end
                    end
                case 'YXCT'
                    if ~isempty(DataRegion)
                        if length(size(DataRegion))>2
                            CurrentImage(~DataRegion(:,:,Channel,Frame))=NaN;
                        else
                            CurrentImage(~DataRegion)=NaN;
                        end
                    end
                case 'YXZC'
                    if ~isempty(DataRegion)
                        if length(size(DataRegion))>2
                            CurrentImage(~DataRegion(:,:,Slice,Channel))=NaN;
                        else
                            CurrentImage(~DataRegion)=NaN;
                        end
                    end
                case 'YXCZ'
                    if ~isempty(DataRegion)
                        if length(size(DataRegion))>2
                            CurrentImage(~DataRegion(:,:,Channel,Slice))=NaN;
                        else
                            CurrentImage(~DataRegion)=NaN;
                        end
                    end
                case 'YXZTC'
                    if ~isempty(DataRegion)
                        if length(size(DataRegion))>2
                            CurrentImage(~DataRegion(:,:,Slice,Frame,Channel))=NaN;
                        else
                            CurrentImage(~DataRegion)=NaN;
                        end
                    end
                case 'YXTZC'
                    if ~isempty(DataRegion)
                        if length(size(DataRegion))>2
                            CurrentImage(~DataRegion(:,:,Frame,Slice,Channel))=NaN;
                        else
                            CurrentImage(~DataRegion)=NaN;
                        end
                    end
                case 'YX[RGB]T'
                case 'YXT[RGB]'
            end
            switch StackOrder
                case 'YXT'
                    ImageArray(:,:,Frame)=CurrentImage;
                case 'YXZ'
                    ImageArray(:,:,Slice)=CurrentImage;
                case 'YXC'
                    ImageArray(:,:,Channel)=CurrentImage;
                case 'YXZT'
                    ImageArray(:,:,Slice,Frame)=CurrentImage;
                case 'YXTZ'
                    ImageArray(:,:,Frame,Slice)=CurrentImage;
                case 'YXTC'
                    ImageArray(:,:,Frame,Channel)=CurrentImage;
                case 'YXCT'
                    ImageArray(:,:,Channel,Frame)=CurrentImage;
                case 'YXZC'
                    ImageArray(:,:,Slice,Channel)=CurrentImage;
                case 'YXCZ'
                    ImageArray(:,:,Channel,Slice)=CurrentImage;
                case 'YXZTC'
                    ImageArray(:,:,Channel,Slice)=CurrentImage;
                case 'YXTZC'
                    ImageArray(:,:,Channel,Slice)=CurrentImage;
                case 'YX[RGB]T'
                case 'YXT[RGB]'
            end
            Channel_Info(Channel).Overall_MeanValues(Frame)=nanmean(CurrentImage(:));
            Channel_Info(Channel).Slice(Slice).Overall_MeanValues(Frame)=nanmean(CurrentImage(:));
            [~,~,~,Channel_Info(Channel).All_Pixels_Bin_Centers,Channel_Info(Channel).All_Pixels_Hist,Channel_Info(Channel).All_Pixels_Hist_Norm,...
                ~,~]=ImageHistograms(ImageArray(:),Channel_Info(Channel).DataRange,Channel_Info(Channel).StepUnits(2));
            if Z_Stack
                TempStack=[];
                switch StackOrder
                    case 'YXT'
                    case 'YXZ'
                        TempStack=squeeze(ImageArray(:,:,Slice));
                    case 'YXC'
                    case 'YXZT'
                        TempStack=squeeze(ImageArray(:,:,Slice,:));
                    case 'YXTZ'
                        TempStack=squeeze(ImageArray(:,:,:,Slice));
                    case 'YXTC'
                    case 'YXCT'
                    case 'YXZC'
                        TempStack=squeeze(ImageArray(:,:,Slice,:));
                    case 'YXCZ'
                        TempStack=squeeze(ImageArray(:,:,:,Slice));
                    case 'YXZTC'
                        TempStack=squeeze(ImageArray(:,:,Slice,:,:));
                    case 'YXTZC'
                        TempStack=squeeze(ImageArray(:,:,:,Slice,:));
                    case 'YX[RGB]T'
                    case 'YXT[RGB]'
                end
                if ~isempty(TempStack)
                    [~,~,~,Channel_Info(Channel).SliceInfo(Slice).All_Pixels_Bin_Centers,Channel_Info(Channel).SliceInfo(Slice).All_Pixels_Hist,Channel_Info(Channel).SliceInfo(Slice).All_Pixels_Hist_Norm,...
                        ~,~]=ImageHistograms(TempStack(:),Channel_Info(Channel).DataRange,Channel_Info(Channel).StepUnits(2));
                else
                    Channel_Info(Channel).SliceInfo(Slice).All_Pixels_Bin_Centers=[];
                    Channel_Info(Channel).SliceInfo(Slice).All_Pixels_Hist=[];
                    Channel_Info(Channel).SliceInfo(Slice).All_Pixels_Hist_Norm=[];
                end
                clear TempStack
            end
        end
        function EditData(~,~,~)
            if TileChannels||TileSlices||TileFrames||Z_Projection||T_Projection
                WarningPopup = questdlg({'Please Exit Tiling/Projection Mode to Edit Data'},'Problem Encountered!','OK','OK');
            else
                if Channel_Info(Channel).Editable
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    set(MakeChannelEditableButton, 'Enable', 'off');
                    set(EditDataButton, 'Enable', 'off');
                    set(UndoEditButton,'Enable','off');
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    EditMode = questdlg({'Edit Mode?';'ROI: Choose Region to Delete';'Area: Choose Continuous Area to Delete';'Image: Delete Whole Frame/Slice'},...
                        'Edit Mode?','ROI','Area','Image','ROI');
                    switch EditMode
                        case 'ROI'
                            axes(ViewerImageAxis);
                            EditRegion=roipoly;
%                             if ~ReleaseFig
%                                 uiwait(ViewerFig);
%                             end
                        case 'Area'
                            axes(ViewerImageAxis);
                            EditRegion=bwselect;
                        case 'Image'
                            EditRegion=ones(ImageHeight,ImageWidth,'logical');
                    end
                    EditRegion=logical(max(EditRegion,[],3));
                    e=length(EditRecord)+1;
                    EditRecord(e).EditMode=EditMode;
                    EditRecord(e).Channel=Channel;
                    EditRecord(e).Frame=Frame;
                    EditRecord(e).Slice=Slice;
                    EditRecord(e).EditRegion=EditRegion;
                    [EditRecord(e).EditRegion,EditRecord(e).EditData,EditRecord(e).EditRegionBorderLine]=...
                        ApplyEdit(EditRecord(e).EditRegion,EditRecord(e).Channel,EditRecord(e).Frame,EditRecord(e).Slice,StackOrder,EditRecord(e).EditMode);
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    %UpdateDisplay
                    CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                    [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    if ~RGB_Stack
                        if T_Stack
                            TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                        end
                        if LiveHist
                            HistDisplay(HistAxis,HistAxisPosition);
                        end
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    set(MakeChannelEditableButton, 'Enable', 'on');
                    set(EditDataButton, 'Enable', 'on');
                    if ~isempty(EditRecord)
                        set(UndoEditButton,'Enable','on');
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                else
                    warning('Non-Editable Channel Currently Active...')
                end
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        function UndoEdit(~,~,~)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(EditDataButton, 'Enable', 'off');
            set(UndoEditButton,'Enable','off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if Channel_Info(Channel).Editable
                if ~isempty(EditRecord)
                    e=length(EditRecord);
                    UndoChannel=EditRecord(e).Channel;
                    UndoFrame=EditRecord(e).Frame;
                    UndoSlice=EditRecord(e).Slice;
                    switch StackOrder
                        case 'YXT'
                            CurrentImage=ImageArray(:,:,UndoFrame);
                        case 'YXZ'
                            CurrentImage=ImageArray(:,:,UndoSlice);
                        case 'YXC'
                            CurrentImage=ImageArray(:,:,UndoChannel);
                        case 'YXZT'
                            CurrentImage=ImageArray(:,:,UndoSlice,UndoFrame);
                        case 'YXTZ'
                            CurrentImage=ImageArray(:,:,UndoFrame,UndoSlice);
                        case 'YXTC'
                            CurrentImage=ImageArray(:,:,UndoFrame,UndoChannel);
                        case 'YXCT'
                            CurrentImage=ImageArray(:,:,UndoChannel,UndoFrame);
                        case 'YXZC'
                            CurrentImage=ImageArray(:,:,UndoSlice,UndoChannel);
                        case 'YXCZ'
                            CurrentImage=ImageArray(:,:,UndoChannel,UndoSlice);
                        case 'YXZTC'
                            CurrentImage=ImageArray(:,:,UndoChannel,UndoSlice);
                        case 'YXTZC'
                            CurrentImage=ImageArray(:,:,UndoChannel,UndoSlice);
                        case 'YX[RGB]T'
                        case 'YXT[RGB]'
                    end
                    CurrentImage=squeeze(CurrentImage);
                    CurrentImage(EditRecord(e).EditRegion)=EditRecord(e).EditData(EditRecord(e).EditRegion);
                    switch StackOrder
                        case 'YXT'
                            ImageArray(:,:,UndoFrame)=CurrentImage;
                        case 'YXZ'
                            ImageArray(:,:,UndoSlice)=CurrentImage;
                        case 'YXC'
                            ImageArray(:,:,UndoChannel)=CurrentImage;
                        case 'YXZT'
                            ImageArray(:,:,UndoSlice,UndoFrame)=CurrentImage;
                        case 'YXTZ'
                            ImageArray(:,:,UndoFrame,UndoSlice)=CurrentImage;
                        case 'YXTC'
                            ImageArray(:,:,UndoFrame,UndoChannel)=CurrentImage;
                        case 'YXCT'
                            ImageArray(:,:,UndoChannel,UndoFrame)=CurrentImage;
                        case 'YXZC'
                            ImageArray(:,:,UndoSlice,UndoChannel)=CurrentImage;
                        case 'YXCZ'
                            ImageArray(:,:,UndoChannel,UndoSlice)=CurrentImage;
                        case 'YXZTC'
                            ImageArray(:,:,UndoChannel,UndoSlice)=CurrentImage;
                        case 'YXTZC'
                            ImageArray(:,:,UndoChannel,UndoSlice)=CurrentImage;
                        case 'YX[RGB]T'
                        case 'YXT[RGB]'
                    end
                    Channel=EditRecord(e).Channel;
                    Frame=EditRecord(e).Frame;
                    Slice=EditRecord(e).Slice;
                    Channel_Info(Channel).Overall_MeanValues(Frame)=nanmean(CurrentImage(:));
                    Channel_Info(Channel).Slice(Slice).Overall_MeanValues(Frame)=nanmean(CurrentImage(:));
                    [~,~,~,Channel_Info(Channel).All_Pixels_Bin_Centers,Channel_Info(Channel).All_Pixels_Hist,Channel_Info(Channel).All_Pixels_Hist_Norm,...
                        ~,~]=ImageHistograms(ImageArray(:),Channel_Info(Channel).DataRange,Channel_Info(Channel).StepUnits(2));
                    if Z_Stack
                        TempStack=[];
                        switch StackOrder
                            case 'YXT'
                            case 'YXZ'
                                TempStack=squeeze(ImageArray(:,:,zz));
                            case 'YXC'
                            case 'YXZT'
                                TempStack=squeeze(ImageArray(:,:,zz,:));
                            case 'YXTZ'
                                TempStack=squeeze(ImageArray(:,:,:,zz));
                            case 'YXTC'
                            case 'YXCT'
                            case 'YXZC'
                                TempStack=squeeze(ImageArray(:,:,zz,:));
                            case 'YXCZ'
                                TempStack=squeeze(ImageArray(:,:,:,zz));
                            case 'YXZTC'
                                TempStack=squeeze(ImageArray(:,:,zz,:,:));
                            case 'YXTZC'
                                TempStack=squeeze(ImageArray(:,:,:,zz,:));
                            case 'YX[RGB]T'
                            case 'YXT[RGB]'
                        end
                        if ~isempty(TempStack)
                            [~,~,~,Channel_Info(Channel).SliceInfo(Slice).All_Pixels_Bin_Centers,Channel_Info(Channel).SliceInfo(Slice).All_Pixels_Hist,Channel_Info(Channel).SliceInfo(Slice).All_Pixels_Hist_Norm,...
                                ~,~]=ImageHistograms(TempStack(:),Channel_Info(Channel).DataRange,Channel_Info(Channel).StepUnits(2));
                        else
                            Channel_Info(Channel).SliceInfo(Slice).All_Pixels_Bin_Centers=[];
                            Channel_Info(Channel).SliceInfo(Slice).All_Pixels_Hist=[];
                            Channel_Info(Channel).SliceInfo(Slice).All_Pixels_Hist_Norm=[];
                        end
                        clear TempStack
                    end
                    if length(EditRecord)>1
                        EditRecord=EditRecord(1:e-1);
                    else
                        EditRecord=[];
                    end
                    set(ColorMapList,'Value',Channel_Info(Channel).DisplayColorMapIndex);
                    set(ChannelLabelText,'String',Channel_Labels{Channel});
                    set(ChannelPos,'String',num2str(Channel));
                    set(Channel_sld,'Value',Channel)
                    set(SlicePos,'String',num2str(Slice));
                    set(Slice_sld,'Value',Slice)
                    set(FramePos,'String',num2str(Frame));
                    set(Frame_sld,'Value',Frame)
                    CurrentTraceYData=Channel_Info(Channel).Overall_MeanValues;
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    %UpdateDisplay
                    %SetColorMap;
                    ColorBarDisplay(ViewerFig,ColorBarAxis,ColorBarAxisPosition);
                    if Z_Projection&&~T_Projection
                        set(LowDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(1)))
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)))
                        warning off
                        set(Low_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1))
                        set(High_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                    elseif ~Z_Projection&&T_Projection
                        set(LowDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(1)))
                        set(HighDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(2)))
                        warning off
                        set(Low_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1))
                        set(High_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                    elseif Z_Projection&&T_Projection
                        error('Not Currently Possible')
                    else
                        set(LowDisp,'String',num2str(Channel_Info(Channel).Display_Limits(1)))
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Display_Limits(2)))
                        warning off
                        set(Low_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(1))
                        set(High_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                        warning on
                    end
                    warning on
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    %UpdateDisplay
                    CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                    [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    if ~RGB_Stack
                        if T_Stack
                            TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                        end
                        if LiveHist
                            HistDisplay(HistAxis,HistAxisPosition);
                        end
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                else
                    warning('NO EDITS YET!')
                end
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(EditDataButton, 'Enable', 'on');
            if ~isempty(EditRecord)
                set(UndoEditButton,'Enable','on');
            end
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        function DisplayEdits(~,~,~)
            DisplayEditsOn = get(DisplayEditsButton,'Value');    
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(DisplayEditsButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(DisplayEditsButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
        function DisplayEditsFormat(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            set(DisplayEditsFormatButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if DisplayEditsOn
                prompt = {'Edits Border Color (ex w r g)','Edits Border Line Style','Edits Border Line Width'};
                dlg_title = 'Scalebar';
                num_lines = 1;
                def = { EditsBorderColor,...
                        EditsBorderLineStyle,...
                        num2str(EditsBorderWidth)};
                answer = inputdlg(prompt,dlg_title,num_lines,def);
                EditsBorderColor=                answer{1};
                EditsBorderLineStyle=            answer{2};
                EditsBorderWidth=                str2num(answer{3});
                clear answer
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(DisplayEditsFormatButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function HistDisplay(HistAxis,HistAxisPosition)
            if isvalid(HistAxis)
                axes(HistAxis);
                cla(HistAxis,'reset')
            else
                HistAxis=axes('position',HistAxisPosition);
            end
            MergeHist=0;
            MergeHistChannels=[];
            if MergeChannel
                MergeHist=1;
                MergeHistChannels=Channels2Merge;
            else
                if TileChannels
                    MergeHist=1;
                    MergeHistChannels=TileSettings.C_Range;
                end
            end
            if SliceHist
                if TileSlices
                    SliceHistRange=[Slice];
                else
                    SliceHistRange=[Slice];
                end
            else
                if TileSlices
                    SliceHistRange=TileSettings.Z_Range;
                else
                    SliceHistRange=[1:Last_Z];
                end
            end
            if MergeHist
                TempXMax=-100000000000;
                TempYMax=-100000000000;
                TempXMin=100000000000;
                TempYMin=100000000000;
                HoldChannel=Channel;
                for c1=1:length(MergeHistChannels)
                    c=MergeHistChannels(c1);
                    if c>0
                        Channel=c;
                        if ischar(Channel_Info(c).DisplayColorMap)
                            if length(Channel_Info(c).DisplayColorMap)==1
                                TempColor=Channel_Info(c).DisplayColorMap;
                            else
                                TempColor='k';
                            end
                        else
                            TempColor=Channel_Info(c).DisplayColorMap;
                        end
                        if strcmp(TempColor,'w')
                            TempColor=[0.3,0.3,0.3];
                        end
                        if LiveHist
                            CurrentImage=[];
                            for z1=1:length(SliceHistRange)
                                z=SliceHistRange(z1);
                                CurrentImages=FindCurrentImage(Channel,Frame,z,StackOrder,Z_Projection,T_Projection,MergeChannel,1,0,0,0,[]);
                                for i=1:length(CurrentImages)
                                    CurrentImage=cat(3,CurrentImage,CurrentImages(i).CurrentImage);
                                end
                            end
                            [~,~,~,LiveFrame_Bin_Centers,LiveFrame_Hist,LiveFrame_Hist_Norm,...
                                ~,~]=ImageHistograms(CurrentImage(:),Channel_Info(c).DataRange,Channel_Info(c).StepUnits(2));
                            if OverallHist
%                                 if SliceHist
%                                     TempXMax=max([TempXMax,max(Channel_Info(c).SliceInfo(Slice).All_Pixels_Bin_Centers)]);
%                                     TempXMin=min([TempXMin,min(Channel_Info(c).SliceInfo(Slice).All_Pixels_Bin_Centers)]);
%                                     hold on
%                                     if NormHist
%                                         AllPixelHist=plot(Channel_Info(c).SliceInfo(Slice).All_Pixels_Bin_Centers,Channel_Info(c).SliceInfo(Slice).All_Pixels_Hist_Norm,'-','color',TempColor,'linewidth',1);
%                                         TempYMax=max([TempYMax,max(Channel_Info(c).SliceInfo(Slice).All_Pixels_Hist_Norm)]);
%                                         TempYMin=min([TempYMin,min(Channel_Info(c).SliceInfo(Slice).All_Pixels_Hist_Norm)]);
%                                     else
%                                         AllPixelHist=plot(Channel_Info(c).SliceInfo(Slice).All_Pixels_Bin_Centers,Channel_Info(c).SliceInfo(Slice).All_Pixels_Hist,'-','color',TempColor,'linewidth',1);
%                                         TempYMax=max([TempYMax,max(Channel_Info(c).SliceInfo(Slice).All_Pixels_Hist)]);
%                                         TempYMin=min([TempYMin,min(Channel_Info(c).SliceInfo(Slice).All_Pixels_Hist)]);
%                                     end
%                                 else
                                    TempXMax=max([TempXMax,max(Channel_Info(c).All_Pixels_Bin_Centers)]);
                                    TempXMin=min([TempXMin,min(Channel_Info(c).All_Pixels_Bin_Centers)]);
                                    hold on
                                    if NormHist
                                        AllPixelHist=plot(Channel_Info(c).All_Pixels_Bin_Centers,Channel_Info(c).All_Pixels_Hist_Norm,'-','color',TempColor,'linewidth',1);
                                        TempYMax=max([TempYMax,max(Channel_Info(c).All_Pixels_Hist_Norm)]);
                                        TempYMin=min([TempYMin,min(Channel_Info(c).All_Pixels_Hist_Norm)]);
                                    else
                                        AllPixelHist=plot(Channel_Info(c).All_Pixels_Bin_Centers,Channel_Info(c).All_Pixels_Hist,'-','color',TempColor,'linewidth',1);
                                        TempYMax=max([TempYMax,max(Channel_Info(c).All_Pixels_Hist)]);
                                        TempYMin=min([TempYMin,min(Channel_Info(c).All_Pixels_Hist)]);
                                    end
%                                 end
                            else
                                TempXMax=max([TempXMax,max(LiveFrame_Bin_Centers)]);
                                TempXMin=min([TempXMin,min(LiveFrame_Bin_Centers)]);
                                hold on
                                if NormHist
                                    AllPixelHist=plot(LiveFrame_Bin_Centers,LiveFrame_Hist_Norm,'-','color',TempColor,'linewidth',1);
                                    TempYMax=max([TempYMax,max(LiveFrame_Hist_Norm)]);
                                    TempYMin=min([TempYMin,min(LiveFrame_Hist_Norm)]);
                                else
                                    AllPixelHist=plot(LiveFrame_Bin_Centers,LiveFrame_Hist,'-','color',TempColor,'linewidth',1);
                                    TempYMax=max([TempYMax,max(LiveFrame_Hist)]);
                                    TempYMin=min([TempYMin,min(LiveFrame_Hist)]);
                                end
                            end
                            TempXMax=max([TempXMax,max(LiveFrame_Bin_Centers)]);
                            TempXMin=min([TempXMin,min(LiveFrame_Bin_Centers)]);
                            hold on
                            if NormHist
                                LiveHistTrace=plot(LiveFrame_Bin_Centers,LiveFrame_Hist_Norm,'-','color',TempColor,'linewidth',0.5);
                                TempYMax=max([TempYMax,max(LiveFrame_Hist_Norm)]);
                                TempYMin=min([TempYMin,min(LiveFrame_Hist_Norm)]);
                            else
                                LiveHistTrace=plot(LiveFrame_Bin_Centers,LiveFrame_Hist,'-','color',TempColor,'linewidth',0.5);
                                TempYMax=max([TempYMax,max(LiveFrame_Hist)]);
                                TempYMin=min([TempYMin,min(LiveFrame_Hist)]);
                            end
                        else
                            if exist('LiveHistTrace')
                                if ~isempty(LiveHistTrace)
                                    delete(LiveHistTrace)
                                end
                            end
                            if SliceHist
                                TempXMax=max([TempXMax,max(Channel_Info(c).SliceInfo(Slice).All_Pixels_Bin_Centers)]);
                                TempXMin=min([TempXMin,min(Channel_Info(c).SliceInfo(Slice).All_Pixels_Bin_Centers)]);
                                hold on
                                if NormHist
                                    AllPixelHist=plot(Channel_Info(c).SliceInfo(Slice).All_Pixels_Bin_Centers,Channel_Info(c).SliceInfo(Slice).All_Pixels_Hist_Norm,'-','color',TempColor,'linewidth',1);
                                    TempYMax=max([TempYMax,max(Channel_Info(c).SliceInfo(Slice).All_Pixels_Hist_Norm)]);
                                    TempYMin=min([TempYMin,min(Channel_Info(c).SliceInfo(Slice).All_Pixels_Hist_Norm)]);
                                else
                                    AllPixelHist=plot(Channel_Info(c).SliceInfo(Slice).All_Pixels_Bin_Centers,Channel_Info(c).SliceInfo(Slice).All_Pixels_Hist,'-','color',TempColor,'linewidth',1);
                                    TempYMax=max([TempYMax,max(Channel_Info(c).SliceInfo(Slice).All_Pixels_Hist)]);
                                    TempYMin=min([TempYMin,min(Channel_Info(c).SliceInfo(Slice).All_Pixels_Hist)]);
                                end
                            else
                                TempXMax=max([TempXMax,max(Channel_Info(c).All_Pixels_Bin_Centers)]);
                                TempXMin=min([TempXMin,min(Channel_Info(c).All_Pixels_Bin_Centers)]);
                                hold on
                                if NormHist
                                    AllPixelHist=plot(Channel_Info(c).All_Pixels_Bin_Centers,Channel_Info(c).All_Pixels_Hist_Norm,'-','color',TempColor,'linewidth',1);
                                    TempYMax=max([TempYMax,max(Channel_Info(c).All_Pixels_Hist_Norm)]);
                                    TempYMin=min([TempYMin,min(Channel_Info(c).All_Pixels_Hist_Norm)]);
                                else
                                    AllPixelHist=plot(Channel_Info(c).All_Pixels_Bin_Centers,Channel_Info(c).All_Pixels_Hist,'-','color',TempColor,'linewidth',1);
                                    TempYMax=max([TempYMax,max(Channel_Info(c).All_Pixels_Hist)]);
                                    TempYMin=min([TempYMin,min(Channel_Info(c).All_Pixels_Hist)]);
                                end
                            end
                        end
                    end
                end
                Channel=HoldChannel;
                xlim([TempXMin,TempXMax])
                if LogHistY
                    ylim([TempYMin,TempYMax])
                else
                    ylim([0,TempYMax])
                end
            else
                if LiveHist
                    CurrentImage=[];
                    for z1=1:length(SliceHistRange)
                        z=SliceHistRange(z1);
                        CurrentImages=FindCurrentImage(Channel,Frame,z,StackOrder,Z_Projection,T_Projection,MergeChannel,1,0,0,0,[]);
                        for i=1:length(CurrentImages)
                            CurrentImage=cat(3,CurrentImage,CurrentImages(i).CurrentImage);
                        end
                    end
                    [~,~,~,LiveFrame_Bin_Centers,LiveFrame_Hist,LiveFrame_Hist_Norm,...
                        ~,~]=ImageHistograms(CurrentImage(:),Channel_Info(Channel).DataRange,Channel_Info(Channel).StepUnits(2));
                    PlotColor='k';
                    if OverallHist
                        if NormHist
                            AllPixelHist=plot(Channel_Info(Channel).All_Pixels_Bin_Centers,Channel_Info(Channel).All_Pixels_Hist_Norm,'-','color',PlotColor,'linewidth',1);
                        else
                            AllPixelHist=plot(Channel_Info(Channel).All_Pixels_Bin_Centers,Channel_Info(Channel).All_Pixels_Hist,'-','color',PlotColor,'linewidth',1);
                        end
                    end
                    if C_Stack
                        if length(Channel_Info(Channel).DisplayColorMap)==1
                            PlotColor=Channel_Info(Channel).DisplayColorMap;
                        else
                            PlotColor=[0.5,0.5,0.5];
                        end
                    else
                        PlotColor=[0.5,0.5,0.5];
                    end
                    if NormHist
                        LiveHistTrace=plot(LiveFrame_Bin_Centers,LiveFrame_Hist_Norm,'-','color',PlotColor,'linewidth',0.5);
                    else
                        LiveHistTrace=plot(LiveFrame_Bin_Centers,LiveFrame_Hist,'-','color',PlotColor,'linewidth',0.5);
                    end
                else
                    if exist('LiveHistTrace')
                        if ~isempty(LiveHistTrace)
                            delete(LiveHistTrace)
                        end
                    end
                    PlotColor='k';
                    if SliceHist
                        if NormHist
                            AllPixelHist=plot(Channel_Info(Channel).SliceInfo(Slice).All_Pixels_Bin_Centers,Channel_Info(Channel).SliceInfo(Slice).All_Pixels_Hist_Norm,'-','color',PlotColor,'linewidth',1);
                        else
                            AllPixelHist=plot(Channel_Info(Channel).SliceInfo(Slice).All_Pixels_Bin_Centers,Channel_Info(Channel).SliceInfo(Slice).All_Pixels_Hist,'-','color',PlotColor,'linewidth',1);
                        end
                    else
                        if NormHist
                            AllPixelHist=plot(Channel_Info(Channel).All_Pixels_Bin_Centers,Channel_Info(Channel).All_Pixels_Hist_Norm,'-','color',PlotColor,'linewidth',1);
                        else
                            AllPixelHist=plot(Channel_Info(Channel).All_Pixels_Bin_Centers,Channel_Info(Channel).All_Pixels_Hist,'-','color',PlotColor,'linewidth',1);
                        end
                    end
                end
                xlim(Channel_Info(Channel).DataRange)
                if LogHistY
                    if NormHist
                        ylim([MinNormTotalPixelCount,1])
                    else
                        if OverallHist
                            ylim([MinNormTotalPixelCount,max(Channel_Info(Channel).All_Pixels_Hist(:))])
                        else
                            if exist('LiveFrame_Hist')
                                ylim([MinNormImagePixelCount,max(LiveFrame_Hist(:))])
                            else
                                ylim([MinNormImagePixelCount,1])
                            end
                        end
                    end
                else
                    if NormHist
                        ylim([0,1])
                    else
                        if OverallHist
                            ylim([0,max(Channel_Info(Channel).All_Pixels_Hist(:))])
                        else
                            if exist('LiveFrame_Hist')
                                ylim([0,max(LiveFrame_Hist(:))])
                            else
                                ylim([0,1])
                            end
                        end
                    end
                end
            end
            XLimits=xlim;
            YLimits=ylim;
            hold on        
            if LogHistX
               set(HistAxis,'xscale','log')
            else
               set(HistAxis,'xscale','linear')
            end
            if LogHistY
               set(HistAxis,'yscale','log')
            else
               set(HistAxis,'yscale','linear')
            end
            xlabel('Pixel Intensity')
            if NormHist
                ylabel('Normalized Pixel Counts')
            else
                ylabel('Pixel Counts')
            end
            if exist('HistLow')
                delete(HistLow)
            end
            if exist('HistHigh')
                delete(HistHigh)
            end
            if exist('HistMask')
                delete(HistMask)
            end
            if NormHist
                if LiveHist
                    HistLow=plot([Channel_Info(Channel).Display_Limits(1),Channel_Info(Channel).Display_Limits(1),Channel_Info(Channel).Display_Limits(1)],...
                        [0,MinNormImagePixelCount,1],...
                        Thresh_LineStyle,'color',ThreshLow_LineColor,'linewidth',Thresh_LineWidth);
                    HistHigh=plot([Channel_Info(Channel).Display_Limits(2),Channel_Info(Channel).Display_Limits(2),Channel_Info(Channel).Display_Limits(2)],...
                        [0,MinNormImagePixelCount,1],...
                        Thresh_LineStyle,'color',ThreshHigh_LineColor,'linewidth',Thresh_LineWidth);
                    if MaskOn
                        HistMask=plot([Channel_Info(Channel).MaskLim,Channel_Info(Channel).MaskLim,Channel_Info(Channel).MaskLim],...
                            [0,MinNormImagePixelCount,1],'--','color','r','linewidth',1);
                    end
                else
                    HistLow=plot([Channel_Info(Channel).Display_Limits(1),Channel_Info(Channel).Display_Limits(1),Channel_Info(Channel).Display_Limits(1)],...
                        [0,MinNormTotalPixelCount,1],...
                        Thresh_LineStyle,'color',ThreshLow_LineColor,'linewidth',Thresh_LineWidth);
                    HistHigh=plot([Channel_Info(Channel).Display_Limits(2),Channel_Info(Channel).Display_Limits(2),Channel_Info(Channel).Display_Limits(2)],...
                        [0,MinNormTotalPixelCount,1],...
                        Thresh_LineStyle,'color',ThreshHigh_LineColor,'linewidth',Thresh_LineWidth);
                    if MaskOn
                        HistMask=plot([Channel_Info(Channel).MaskLim,Channel_Info(Channel).MaskLim,Channel_Info(Channel).MaskLim],...
                            [0,MinNormTotalPixelCount,1],...
                            '--','color',ThreshMask_LineColor,'linewidth',Thresh_LineWidth);
                    end
                end
            else
                if LiveHist
                    HistLow=plot([Channel_Info(Channel).Display_Limits(1),Channel_Info(Channel).Display_Limits(1),Channel_Info(Channel).Display_Limits(1)],...
                        [0,MinNormImagePixelCount,YLimits(2)],...
                        Thresh_LineStyle,'color',ThreshLow_LineColor,'linewidth',Thresh_LineWidth);
                    HistHigh=plot([Channel_Info(Channel).Display_Limits(2),Channel_Info(Channel).Display_Limits(2),Channel_Info(Channel).Display_Limits(2)],...
                        [0,MinNormImagePixelCount,YLimits(2)],...
                        Thresh_LineStyle,'color',ThreshHigh_LineColor,'linewidth',Thresh_LineWidth);
                    if MaskOn
                        HistMask=plot([Channel_Info(Channel).MaskLim,Channel_Info(Channel).MaskLim,Channel_Info(Channel).MaskLim],...
                            [0,MinNormImagePixelCount,YLimits(2)],'--','color','r','linewidth',1);
                    end
                else
                    HistLow=plot([Channel_Info(Channel).Display_Limits(1),Channel_Info(Channel).Display_Limits(1),Channel_Info(Channel).Display_Limits(1)],...
                        [0,MinNormTotalPixelCount,YLimits(2)],...
                        Thresh_LineStyle,'color',ThreshLow_LineColor,'linewidth',Thresh_LineWidth);
                    HistHigh=plot([Channel_Info(Channel).Display_Limits(2),Channel_Info(Channel).Display_Limits(2),Channel_Info(Channel).Display_Limits(2)],...
                        [0,MinNormTotalPixelCount,YLimits(2)],...
                        Thresh_LineStyle,'color',ThreshHigh_LineColor,'linewidth',Thresh_LineWidth);
                    if MaskOn
                        HistMask=plot([Channel_Info(Channel).MaskLim,Channel_Info(Channel).MaskLim,Channel_Info(Channel).MaskLim],...
                            [0,MinNormTotalPixelCount,YLimits(2)],...
                            Thresh_LineStyle,'color',ThreshMask_LineColor,'linewidth',Thresh_LineWidth);
                    end
                end
            end
            xlim(XLimits)
            ylim(YLimits)
            %set(HistAxis,'TickDir','out');
            set(HistAxis,'TickLength',[0.02, 0.005])
            set(HistAxis,'units','normalized','Position', HistAxisPosition)
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function TraceDisplay(TraceLim,Channel,Frame,CurrentSlices,CurrentFig,CurrentTracePlotAxis,CurrentTraceAxisPosition,SplitTraceAdjust)
            if T_Stack
                TraceCount=0;
                if isvalid(CurrentTracePlotAxis)
                    if CurrentFig==ViewerFig
                        axes(CurrentTracePlotAxis);
                        cla(CurrentTracePlotAxis)
                    end
                else
                    CurrentTracePlotAxis=axes('position',CurrentTraceAxisPosition);
                end
                if CurrentFig==ViewerFig
                    if exist('CurrentFrameMarker')
                        delete(CurrentFrameMarker)
                    end
                end
                hold on
                TempMaxY=-10000000000;
                TempMinY=10000000000;
                for z1=1:length(CurrentSlices)
                    z0=CurrentSlices(z1);
                    if MeanTraces
                        if MergeChannel
                            %TempMaxY=-10000000000;
                            %TempMinY=10000000000;
                            for c1=1:length(Channels2Merge)
                                TraceCount=TraceCount+1;
                                c=Channels2Merge(c1);
                                TempMaxY=max(TempMaxY,max(Channel_Info(c).Overall_MeanValues+(TraceCount*SplitTraceAdjust)));
                                TempMinY=min(TempMinY,min(Channel_Info(c).Overall_MeanValues+(TraceCount*SplitTraceAdjust)));
                                if ischar(Channel_Info(c).DisplayColorMap)
                                    if length(Channel_Info(c).DisplayColorMap)==1
                                        TempColor=Channel_Info(c).DisplayColorMap;
                                    else
                                        TempColor='k';
                                    end
                                else
                                    TempColor=Channel_Info(c).DisplayColorMap;
                                end
                                if strcmp(TempColor,'w')
                                    TempColor=[0.3,0.3,0.3];
                                end
                                plot([1:length(Channel_Info(c).Overall_MeanValues)],...
                                    Channel_Info(c).Overall_MeanValues+(TraceCount*SplitTraceAdjust),...
                                    Trace_LineStyle,...
                                    'color',TempColor,'linewidth',MeanTrace_LineWidth)
                            end
                        else
                            TraceCount=TraceCount+1;
                            TempMaxY=max(TempMaxY,max(Channel_Info(Channel).Overall_MeanValues+(TraceCount*SplitTraceAdjust)));
                            TempMinY=min(TempMinY,min(Channel_Info(Channel).Overall_MeanValues+(TraceCount*SplitTraceAdjust)));
                            if ischar(Channel_Info(Channel).DisplayColorMap)
                                if length(Channel_Info(Channel).DisplayColorMap)==1
                                    TempColor=Channel_Info(Channel).DisplayColorMap;
                                else
                                    TempColor='k';
                                end
                            else
                                TempColor=Channel_Info(Channel).DisplayColorMap;
                            end
                            if strcmp(TempColor,'w')
                                TempColor=[0.3,0.3,0.3];
                            end
                            plot([1:length(Channel_Info(Channel).Overall_MeanValues)],...
                                Channel_Info(Channel).Overall_MeanValues+(TraceCount*SplitTraceAdjust),...
                                MeanTrace_LineStyle,...
                                'color',TempColor,'linewidth',MeanTrace_LineWidth)
                        end
                    end
                    if SliceMeanTraces
                        if MergeChannel
                            %TempMaxY=-10000000000;
                            %TempMinY=10000000000;
                            for c1=1:length(Channels2Merge)
                                TraceCount=TraceCount+1;
                                c=Channels2Merge(c1);
                                TempMaxY=max(TempMaxY,max(Channel_Info(c).Slice(z0).Overall_MeanValues+(TraceCount*SplitTraceAdjust)));
                                TempMinY=min(TempMinY,min(Channel_Info(c).Slice(z0).Overall_MeanValues+(TraceCount*SplitTraceAdjust)));
                                if ischar(Channel_Info(c).DisplayColorMap)
                                    if length(Channel_Info(c).DisplayColorMap)==1
                                        TempColor=Channel_Info(c).DisplayColorMap;
                                    else
                                        TempColor='k';
                                    end
                                else
                                    TempColor=Channel_Info(c).DisplayColorMap;
                                end
                                if strcmp(TempColor,'w')
                                    TempColor=[0.3,0.3,0.3];
                                end
                                plot([1:length(Channel_Info(c).Slice(z0).Overall_MeanValues)],...
                                    Channel_Info(c).Slice(z0).Overall_MeanValues+(TraceCount*SplitTraceAdjust),...
                                    SliceMeanTrace_LineStyle,...
                                    'color',TempColor,'linewidth',SliceMeanTrace_LineWidth)
                            end
                        else
                            TraceCount=TraceCount+1;
                            TempMaxY=max(TempMaxY,max(Channel_Info(Channel).Slice(z0).Overall_MeanValues+(TraceCount*SplitTraceAdjust)));
                            TempMinY=min(TempMinY,min(Channel_Info(Channel).Slice(z0).Overall_MeanValues+(TraceCount*SplitTraceAdjust)));
                            if ischar(Channel_Info(Channel).DisplayColorMap)
                                if length(Channel_Info(Channel).DisplayColorMap)==1
                                    TempColor=Channel_Info(Channel).DisplayColorMap;
                                else
                                    TempColor='k';
                                end
                            else
                                TempColor=Channel_Info(Channel).DisplayColorMap;
                            end
                            if strcmp(TempColor,'w')
                                TempColor=[0.3,0.3,0.3];
                            end
                            plot([1:length(Channel_Info(Channel).Slice(z0).Overall_MeanValues)],...
                                Channel_Info(Channel).Slice(z0).Overall_MeanValues+(TraceCount*SplitTraceAdjust),...
                                SliceMeanTrace_LineStyle,...
                                'color',TempColor,'linewidth',SliceMeanTrace_LineWidth)
                        end
                    end
                    if ~isempty(ROIs)&&ROITraces
                        for ROI=1:length(ROIs)
                            if TileSlices||Z_Projection||z0==0||z0==ROIs(ROI).Slice%&&Channel==ROIs(NumROIs).Channel
                                TraceCount=TraceCount+1;
                                TempMaxY=max(TempMaxY,max(ROIs(ROI).TraceChannel(Channel).Trace+(TraceCount*SplitTraceAdjust)));
                                TempMinY=min(TempMinY,min(ROIs(ROI).TraceChannel(Channel).Trace+(TraceCount*SplitTraceAdjust)));
                                TempVector=ROIs(ROI).TraceChannel(Channel).Trace+(TraceCount*SplitTraceAdjust);
                                plot(CurrentTraceXData,TempVector,...
                                    Trace_LineStyle,...
                                    'color',ROIs(ROI).Color,'linewidth',Trace_LineWidth)
                                if isfield(ROIs(ROI).TraceChannel,'LocalizationMarkers')
                                    for tt=1:length(ROIs(ROI).TraceChannel(cc).LocalizationMarkers)
                                        if ROIs(ROI).TraceChannel(cc).LocalizationMarkers(tt)>0
                                            TempColor=LocalizationMarkers(ROIs(ROI).TraceChannel(cc).LocalizationMarkers(tt)).Color;
                                            if ischar(TempColor)
                                                if TempColor=='w'
                                                    TempColor=[0.5,0.5,0.5];
                                                end
                                            elseif length(TempColor==[1,1,1])==3
                                                TempColor=[0.5,0.5,0.5];
                                            end
                                            hold on
                                            plot(tt,TempVector(tt),...
                                                LocalizationMarkers(ROIs(ROI).TraceChannel(cc).LocalizationMarkers(tt)).LineMarkerStyle,...
                                                'color',TempColor,...
                                                'markersize',LocalizationMarkers(ROIs(ROI).TraceChannel(cc).LocalizationMarkers(tt)).MarkerSize)
                                        end
                                    end
                                end
                            end
                        end                
                    end
                end
                if ~isempty(TraceLim)
                    xlim(TraceLim)
                else
                    xlim([CurrentTraceXData(1)-1,CurrentTraceXData(length(CurrentTraceXData))])
                end
                if ~MeanTraces&&~SliceMeanTraces&&isempty(ROIs)
                    TempMaxY=1;
                    TempMinY=0;
                end
                Buffer=0.05*abs(TempMaxY-TempMinY);
                if TempMinY<TempMaxY
                    ylim([TempMinY-Buffer,TempMaxY+Buffer]);
                end
                TraceYLimits=ylim;
                hold on
                if CurrentFrameMarkerOn
                    [CurrentFrameMarker]=PlotCurrentFrameMarker(Frame,CurrentFrameMarker,CurrentTracePlotAxis);
                end
                hold on
                if FrameMarkersOn
                    [AllFrameMarkers,AllFrameMarkerLabels]=PlotFrameMarkers(AllFrameMarkers,AllFrameMarkerLabels,FrameMarkers,CurrentTracePlotAxis);
                end
                hold on
                if TraceThreshMarkersOn
                    [TraceLow,TraceHigh,TraceMask]=PlotTraceThreshMarkers(Channel,TraceLow,TraceHigh,TraceMask,CurrentTracePlotAxis);
                end
                xlabel('Frame')
                ylabel('Mean Intensity')
                ylim(TraceYLimits)
                if TraceScaleOn
                    XLimits=xlim;
                    YLimits=ylim;
                    axis(CurrentTracePlotAxis,'off')
                    switch TraceScaleBars.Position
                        case 'BL'
                            TraceScaleBars.HorzXData=[XLimits(1),XLimits(1)+TraceScaleBars.HorzLength/TraceScaleBars.HorzAdjust];
                            TraceScaleBars.HorzYData=[YLimits(1),YLimits(1)];
                            switch TraceScaleBars.HorzTextHorzAlign
                                case 'left'
                                    TraceScaleBars.HorzTextX=TraceScaleBars.HorzXData(1);
                                case 'center'
                                    TraceScaleBars.HorzTextX=mean(TraceScaleBars.HorzXData);
                                case 'right'
                                    TraceScaleBars.HorzTextX=TraceScaleBars.HorzXData(2);
                            end
                            TraceScaleBars.HorzTextY=TraceScaleBars.HorzYData(1);
                            TraceScaleBars.VertXData=[XLimits(1),XLimits(1)];
                            TraceScaleBars.VertYData=[YLimits(1),YLimits(1)+TraceScaleBars.VertLength];
                            TraceScaleBars.VertTextX=TraceScaleBars.VertXData(1);
                            switch TraceScaleBars.VertTextVertAlign
                                case 'top'
                                     TraceScaleBars.VertTextY=TraceScaleBars.VertYData(2);
                               case 'middle'
                                    TraceScaleBars.VertTextY=mean(TraceScaleBars.VertYData);
                                case 'bottom'
                                     TraceScaleBars.VertTextY=TraceScaleBars.VertYData(1);
                            end
                        case 'BR'
                            TraceScaleBars.HorzXData=[XLimits(2)-TraceScaleBars.HorzLength/TraceScaleBars.HorzAdjust,XLimits(2)];
                            TraceScaleBars.HorzYData=[YLimits(1),YLimits(1)];
                            switch TraceScaleBars.HorzTextHorzAlign
                                case 'left'
                                    TraceScaleBars.HorzTextX=TraceScaleBars.HorzXData(1);
                                case 'center'
                                    TraceScaleBars.HorzTextX=mean(TraceScaleBars.HorzXData);
                                case 'right'
                                    TraceScaleBars.HorzTextX=TraceScaleBars.HorzXData(2);
                            end
                            TraceScaleBars.HorzTextY=TraceScaleBars.HorzYData(1);
                            TraceScaleBars.VertXData=[XLimits(2),XLimits(2)];
                            TraceScaleBars.VertYData=[YLimits(1),YLimits(1)+TraceScaleBars.VertLength];
                            TraceScaleBars.VertTextX=TraceScaleBars.VertXData(1);
                            switch TraceScaleBars.VertTextVertAlign
                                case 'top'
                                     TraceScaleBars.VertTextY=TraceScaleBars.VertYData(2);
                               case 'middle'
                                    TraceScaleBars.VertTextY=mean(TraceScaleBars.VertYData);
                                case 'bottom'
                                     TraceScaleBars.VertTextY=TraceScaleBars.VertYData(1);
                            end
                        case 'TL'
                            TraceScaleBars.HorzXData=[XLimits(1),XLimits(1)+TraceScaleBars.HorzLength/TraceScaleBars.HorzAdjust];
                            TraceScaleBars.HorzYData=[YLimits(2),YLimits(2)];
                            switch TraceScaleBars.HorzTextHorzAlign
                                case 'left'
                                    TraceScaleBars.HorzTextX=TraceScaleBars.HorzXData(1);
                                case 'center'
                                    TraceScaleBars.HorzTextX=mean(TraceScaleBars.HorzXData);
                                case 'right'
                                    TraceScaleBars.HorzTextX=TraceScaleBars.HorzXData(2);
                            end
                            TraceScaleBars.HorzTextY=TraceScaleBars.HorzYData(1);
                            TraceScaleBars.VertXData=[XLimits(1),XLimits(1)];
                            TraceScaleBars.VertYData=[YLimits(2)-TraceScaleBars.VertLength,YLimits(2)];
                            TraceScaleBars.VertTextX=TraceScaleBars.VertXData(1);
                            switch TraceScaleBars.VertTextVertAlign
                                case 'top'
                                     TraceScaleBars.VertTextY=TraceScaleBars.VertYData(2);
                               case 'middle'
                                    TraceScaleBars.VertTextY=mean(TraceScaleBars.VertYData);
                                case 'bottom'
                                     TraceScaleBars.VertTextY=TraceScaleBars.VertYData(1);
                            end
                        case 'TR'
                            TraceScaleBars.HorzXData=[XLimits(2)-TraceScaleBars.HorzLength/TraceScaleBars.HorzAdjust,XLimits(2)];
                            TraceScaleBars.HorzYData=[YLimits(2),YLimits(2)];
                            switch TraceScaleBars.HorzTextHorzAlign
                                case 'left'
                                    TraceScaleBars.HorzTextX=TraceScaleBars.HorzXData(1);
                                case 'center'
                                    TraceScaleBars.HorzTextX=mean(TraceScaleBars.HorzXData);
                                case 'right'
                                    TraceScaleBars.HorzTextX=TraceScaleBars.HorzXData(2);
                            end
                            TraceScaleBars.HorzTextY=TraceScaleBars.HorzYData(1);
                            TraceScaleBars.VertXData=[XLimits(2),XLimits(2)];
                            TraceScaleBars.VertYData=[YLimits(2)-TraceScaleBars.VertLength,YLimits(2)];
                            TraceScaleBars.VertTextX=TraceScaleBars.VertXData(1);
                            switch TraceScaleBars.VertTextVertAlign
                                case 'top'
                                     TraceScaleBars.VertTextY=TraceScaleBars.VertYData(2);
                               case 'middle'
                                    TraceScaleBars.VertTextY=mean(TraceScaleBars.VertYData);
                                case 'bottom'
                                     TraceScaleBars.VertTextY=TraceScaleBars.VertYData(1);
                            end
                    end
                    hold on
                    plot(TraceScaleBars.HorzXData,TraceScaleBars.HorzYData,'-','color',TraceScaleBars.LineColor,'linewidth',TraceScaleBars.LineWidth)
                    plot(TraceScaleBars.VertXData,TraceScaleBars.VertYData,'-','color',TraceScaleBars.LineColor,'linewidth',TraceScaleBars.LineWidth)
                    hold on
                    text(TraceScaleBars.HorzTextX,TraceScaleBars.HorzTextY,...
                        [' ',num2str(TraceScaleBars.HorzLength),' ',TraceScaleBars.HorzUnit,' '],...
                        'color',TraceScaleBars.LineColor,'fontsize',TraceScaleBars.FontSize,'fontname','arial',...
                        'horizontalalignment',TraceScaleBars.HorzTextHorzAlign,...
                        'verticalalignment',TraceScaleBars.HorzTextVertAlign)
                    hold on
                    text(TraceScaleBars.VertTextX,TraceScaleBars.VertTextY,...
                        {[' ',Channel_Labels{Channel},' ',num2str(TraceScaleBars.VertLength),' ',TraceScaleBars.VertUnit,' ']},...
                        'color',TraceScaleBars.LineColor,'fontsize',TraceScaleBars.FontSize,'fontname','arial',...
                        'horizontalalignment',TraceScaleBars.VertTextHorzAlign,...
                        'verticalalignment',TraceScaleBars.VertTextVertAlign)
                else
                    axis(CurrentTracePlotAxis,'on')
                    set(CurrentTracePlotAxis,'TickDir','out');
                    set(CurrentTracePlotAxis,'TickLength',[0.001, 0.0005])
                end
                set(CurrentTracePlotAxis,'units','normalized','Position', CurrentTraceAxisPosition)
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function [TraceLow,TraceHigh,TraceMask]=PlotTraceThreshMarkers(Channel,TraceLow,TraceHigh,TraceMask,CurrentTracePlotAxis)
            if T_Stack
                if TraceThreshMarkersOn
                    axes(CurrentTracePlotAxis);
                    if exist('TraceLow')
                        if ~isempty(TraceLow)
                            delete(TraceLow)
                        end
                    end
                    if exist('TraceHigh')
                        if ~isempty(TraceHigh)
                            delete(TraceHigh)
                        end
                    end
                    if exist('TraceMask')
                        if ~isempty(TraceMask)
                            delete(TraceMask)
                        end
                    end       
                    TraceLow=plot([CurrentTraceXData(1),CurrentTraceXData(length(CurrentTraceXData))],...
                        [Channel_Info(Channel).Display_Limits(1),Channel_Info(Channel).Display_Limits(1)],...
                        Thresh_LineStyle,'color',ThreshLow_LineColor,'linewidth',Thresh_LineWidth);
                    TraceHigh=plot([CurrentTraceXData(1),CurrentTraceXData(length(CurrentTraceXData))],...
                        [Channel_Info(Channel).Display_Limits(2),Channel_Info(Channel).Display_Limits(2)],...
                        Thresh_LineStyle,'color',ThreshHigh_LineColor,'linewidth',Thresh_LineWidth);
                    if MaskOn
                        TraceMask=plot([CurrentTraceXData(1),CurrentTraceXData(length(CurrentTraceXData))],...
                            [Channel_Info(Channel).MaskLim,Channel_Info(Channel).MaskLim],...
                            Thresh_LineStyle,'color',ThreshMask_LineColor,'linewidth',Thresh_LineWidth);
                    else
                        TraceMask=[];
                    end
                end
            end
        end
        function [CurrentFrameMarker]=PlotCurrentFrameMarker(Frame,CurrentFrameMarker,CurrentTracePlotAxis)
            if T_Stack
                if CurrentFrameMarkerOn
                    if CurrentTracePlotAxis==TracePlotAxis
                        axes(CurrentTracePlotAxis);
                        if exist('CurrentFrameMarker')
                            delete(CurrentFrameMarker)
                        end
                    end
                    hold on
                    if ~exist('TraceYLimits')
                        TraceYLimits=ylim;
                    end
                    CurrentFrameMarker=plot([Frame,Frame],TraceYLimits,Frame_LineStyle,...
                        'color',Frame_LineColor,'linewidth',Frame_LineWidth);

                end
            end
        end
        function [AllFrameMarkers,AllFrameMarkerLabels]=PlotFrameMarkers(AllFrameMarkers,AllFrameMarkerLabels,FrameMarkers,CurrentTracePlotAxis)
            if T_Stack
                if FrameMarkersOn
                    if CurrentTracePlotAxis==TracePlotAxis
                        axes(CurrentTracePlotAxis);
                        if exist('AllFrameMarkers')
                            for m=1:length(AllFrameMarkers)
                                delete(AllFrameMarkers(m).p)
                            end
                        end
                        if exist('AllFrameMarkerLabels')
                            for m=1:length(AllFrameMarkerLabels)
                                delete(AllFrameMarkerLabels(m).t)
                            end
                        end
                    end
                    hold on
                    if ~exist('TraceYLimits')
                        TraceYLimits=ylim;
                    end
                    m=0;
                    for i=1:length(FrameMarkers)
                        for j=1:length(FrameMarkers(i).Frames)
                            m=m+1;
                            if FrameMarkers(i).Style==1
                                if FrameMarkers(i).MarkerOn
                                    AllFrameMarkers(m).p=plot([FrameMarkers(i).Frames(j),FrameMarkers(i).Frames(j)]+FrameMarkers(i).FrameAdjust,...
                                        [TraceYLimits(1),TraceYLimits(2)],...
                                        FrameMarkers(i).LineMarkerStyle,...
                                        'color',FrameMarkers(i).Color,...
                                        'linewidth',FrameMarkers(i).LineWidth,...
                                        'markersize',FrameMarkers(i).MarkerSize);
                                    if FrameMarkerLabelsOn&&FrameMarkers(i).MarkerTextOn
                                        if ~isempty(FrameMarkers(i).Labels{j})
                                            AllFrameMarkerLabels(m).t=text(...
                                                FrameMarkers(i).Frames(j)+FrameMarkers(i).FrameAdjust+FrameMarkers(i).TextXOffset,...
                                                TraceYLimits(2)+FrameMarkers(i).TextYOffset,...
                                                [' ',FrameMarkers(i).Labels{j}],'color',FrameMarkers(i).Color,...
                                                'fontsize',FrameMarkers(i).FontSize,...
                                                'horizontalalignment',FrameMarkers(i).HorizontalAlignment,...
                                                'verticalalignment',FrameMarkers(i).VerticalAlignment);
                                        end
                                    end
                                end
                            elseif FrameMarkers(i).Style==2
                                if FrameMarkers(i).MarkerOn
                                    AllFrameMarkers(m).p=plot([FrameMarkers(i).Frames{j}]+FrameMarkers(i).FrameAdjust,...
                                        TraceYLimits(2)*ones(length(FrameMarkers(i).Frames{j})),...
                                        FrameMarkers(i).LineMarkerStyle,...
                                        'color',FrameMarkers(i).Color,...
                                        'linewidth',FrameMarkers(i).LineWidth,...
                                        'markersize',FrameMarkers(i).MarkerSize);
                                    if FrameMarkerLabelsOn&&FrameMarkers(i).MarkerTextOn
                                        if ~isempty(FrameMarkers(i).Labels{j})
                                            AllFrameMarkerLabels(m).t=text(...
                                                min(FrameMarkers(i).Frames{j})+FrameMarkers(i).FrameAdjust+FrameMarkers(i).TextXOffset,...
                                                TraceYLimits(2)+FrameMarkers(i).TextYOffset,...
                                                [' ',FrameMarkers(i).Labels{j}],...
                                                'color',FrameMarkers(i).Color,...
                                                'fontsize',FrameMarkers(i).FontSize,...
                                                'horizontalalignment',FrameMarkers(i).HorizontalAlignment,...
                                                'verticalalignment',FrameMarkers(i).VerticalAlignment);
                                        end
                                    end
                                end
                            elseif FrameMarkers(i).Style==3
                                if FrameMarkers(i).MarkerOn
                                    AllFrameMarkers(m).p=plot([FrameMarkers(i).Frames{j}]+FrameMarkers(i).FrameAdjust,...
                                        TraceYLimits(1)*ones(length(FrameMarkers(i).Frames{j})),...
                                        FrameMarkers(i).LineMarkerStyle,...
                                        'color',FrameMarkers(i).Color,...
                                        'linewidth',FrameMarkers(i).LineWidth,...
                                        'markersize',FrameMarkers(i).MarkerSize);
                                    if FrameMarkerLabelsOn&&FrameMarkers(i).MarkerTextOn
                                        if ~isempty(FrameMarkers(i).Labels{j})
                                            AllFrameMarkerLabels(m).t=text(...
                                                min(FrameMarkers(i).Frames{j})+FrameMarkers(i).FrameAdjust+FrameMarkers(i).TextXOffset,...
                                                TraceYLimits(1)+FrameMarkers(i).TextYOffset,...
                                                [' ',FrameMarkers(i).Labels{j}],...
                                                'color',FrameMarkers(i).Color,...
                                                'fontsize',FrameMarkers(i).FontSize,...
                                                'horizontalalignment',FrameMarkers(i).HorizontalAlignment,...
                                                'verticalalignment',FrameMarkers(i).VerticalAlignment);
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function DisplayROIBorders(~,~,~)
            ROIBorders=get(ROIBorders_Button,'value');
            set(ROIBorders_Button, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ROIBorders_Button, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        function DisplayROITraces(~,~,~)
            ROITraces=get(ROITraces_Button,'value');
            set(ROITraces_Button, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ROITraces_Button, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        function DisplayMeanTraces(~,~,~)
            MeanTraces=get(MeanTraces_Button,'value');
            set(MeanTraces_Button, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(MeanTraces_Button, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        function DisplaySliceMeanTraces(~,~,~)
            SliceMeanTraces=get(SliceMeanTraces_Button,'value');
            set(SliceMeanTraces_Button, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(SliceMeanTraces_Button, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        function CurrentFrameMarkerToggle(~,~,~)
            CurrentFrameMarkerOn = get(CurrentFrameMarkerButton,'Value');    
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            set(CurrentFrameMarkerButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(CurrentFrameMarkerButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
        function FrameMarkersToggle(~,~,~)
            FrameMarkersOn = get(FrameMarkersButton,'Value');    
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            set(FrameMarkersButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(FrameMarkersButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
        function FrameMarkerLabelsToggle(~,~,~)
            FrameMarkerLabelsOn = get(FrameMarkerLabelsButton,'Value');    
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            set(FrameMarkerLabelsButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(FrameMarkerLabelsButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
        function TraceThreshMarkerToggle(~,~,~)
            TraceThreshMarkersOn = get(TraceThreshMarkerButton,'Value');    
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            set(TraceThreshMarkerButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(TraceThreshMarkerButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function TraceScaleBar(~,~,~)
            TraceScaleOn = get(TraceScaleButton,'Value');
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            set(TraceScaleButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if TraceScaleOn
                try
                    if isempty(ImagingInfo)
                        CollectImagingInfo
                    end
                    if isempty(TraceScaleBars)
                        if isnan(ImagingInfo.InterFrameTime)||ImagingInfo.InterFrameTime==0
                            TraceScaleBars.HorzLength=ceil(Last_T*0.1);
                            TraceScaleBars.HorzUnit='Frames';
                        else
                            TraceScaleBars.HorzLength=ceil(Last_T*ImagingInfo.InterFrameTime*0.1);
                            TraceScaleBars.HorzUnit=ImagingInfo.FrameUnit;
                        end
                        if isnan(ImagingInfo.InterFrameTime)||ImagingInfo.InterFrameTime==0
                            TraceScaleBars.HorzAdjust=1;
                        else
                            TraceScaleBars.HorzAdjust=ImagingInfo.InterFrameTime;
                        end
                        TraceScaleBars.VertLength=ceil(OverallMaxVal*0.01);
                        TraceScaleBars.VertUnit='AU';
                        TraceScaleBars.FontSize=14;
                        TraceScaleBars.LineColor='k';
                        TraceScaleBars.LineWidth=0.5;
                        TraceScaleBars.Position='TR';
                        TraceScaleBars.XData=[];
                        TraceScaleBars.YData=[];
                    end
                    prompt = {'Horz Length','Horz Unit {ex. s ms frame)',...
                        'Time Between Frames (match unit, 1 if frame)',...
                        'Vert Length','Vert Unit',...
                        'FontSize','LineColor (ex w r g b)',...
                        'LineWidth','Position (BL BR TL TR)'};
                    dlg_title = 'TraceScaleBars';
                    num_lines = 1;
                    def = {num2str(TraceScaleBars.HorzLength),TraceScaleBars.HorzUnit,...
                        num2str(TraceScaleBars.HorzAdjust),...
                        num2str(TraceScaleBars.VertLength),TraceScaleBars.VertUnit,...
                        num2str(TraceScaleBars.FontSize),TraceScaleBars.LineColor,...
                        num2str(TraceScaleBars.LineWidth),TraceScaleBars.Position};
                    answer = inputdlg(prompt,dlg_title,num_lines,def);
                    TraceScaleBars.HorzLength=         str2num(answer{1});
                    TraceScaleBars.HorzUnit=                   answer{2};
                    TraceScaleBars.HorzAdjust=         str2num(answer{3});
                    TraceScaleBars.VertLength=         str2num(answer{4});
                    TraceScaleBars.VertUnit=                   answer{5};
                    TraceScaleBars.FontSize=       str2num(answer{6});
                    TraceScaleBars.LineColor=              answer{7};
                    TraceScaleBars.LineWidth=      str2num(answer{8});
                    TraceScaleBars.Position=               answer{9};
                    clear answer
                    if ~isfield(TraceScaleBars,'HorzTextHorzAlign')
                        switch TraceScaleBars.Position
                            case 'BL'
                                TraceScaleBars.HorzTextHorzAlign='center';
                                TraceScaleBars.HorzTextVertAlign='bottom';
                                TraceScaleBars.VertTextHorzAlign='left';
                                TraceScaleBars.VertTextVertAlign='middle';
                            case 'BR'
                                TraceScaleBars.HorzTextHorzAlign='center';
                                TraceScaleBars.HorzTextVertAlign='bottom';
                                TraceScaleBars.VertTextHorzAlign='right';
                                TraceScaleBars.VertTextVertAlign='middle';
                            case 'TL'
                                TraceScaleBars.HorzTextHorzAlign='center';
                                TraceScaleBars.HorzTextVertAlign='top';
                                TraceScaleBars.VertTextHorzAlign='left';
                                TraceScaleBars.VertTextVertAlign='middle';
                            case 'TR'
                                TraceScaleBars.HorzTextHorzAlign='center';
                                TraceScaleBars.HorzTextVertAlign='top';
                                TraceScaleBars.VertTextHorzAlign='right';
                                TraceScaleBars.VertTextVertAlign='middle';
                        end
                    end
                    prompt = {  'Horz Text Horz Alignment (left/center/right)',...
                                'Vert Text Vert Alignment (top/middle/bottom)',...
                                };
                    dlg_title = 'TraceScaleBars';
                    num_lines = 1;
                    def = { TraceScaleBars.HorzTextHorzAlign,...
                            TraceScaleBars.VertTextVertAlign,...
                          };
                    answer = inputdlg(prompt,dlg_title,num_lines,def);
                    TraceScaleBars.HorzTextHorzAlign=answer{1};
                    TraceScaleBars.VertTextVertAlign=answer{2};
                    clear answer
                catch
                    warning('Problem with TraceScaleBar')
                    TraceScaleOn=0;
                    set(TraceScaleButton,'Value',TraceScaleOn);   
                    set(TraceScaleButton, 'Enable', 'on');

                end
            else
                TraceScaleOn=0;
                set(TraceScaleButton,'Value',TraceScaleOn);    
                set(TraceScaleButton, 'Enable', 'on');
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(TraceScaleButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function ResetTrace(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ResetTraces_Button, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            ROIs=[];
            NumROIs=0;
            ROITraces=0;
            set(ROITraces_Button,'value',ROITraces);
            axes(TracePlotAxis)
            if ~RGB_Stack
                if T_Stack
                    TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                end
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ResetTraces_Button, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
        function FormatTraces(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(FormatTraces_Button, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            prompt = {  'ROI Trace Line Style',...
                        'ROI Trace Line Width',...
                        'Mean Trace Line Style',...
                        'Mean Trace Line Width',...
                        'Slice Mean Trace Line Style',...
                        'Slice Mean Trace Line Width',...
                        };
            dlg_title = 'Trace Format';
            num_lines = 1;
            def = {         Trace_LineStyle,...
                    num2str(Trace_LineWidth)...
                            MeanTrace_LineStyle,...
                    num2str(MeanTrace_LineWidth)...
                            SliceMeanTrace_LineStyle,...
                    num2str(SliceMeanTrace_LineWidth)...
                    };
            answer = inputdlg(prompt,dlg_title,num_lines,def);
            Trace_LineStyle=                   answer{1};
            Trace_LineWidth=           str2num(answer{2});
            MeanTrace_LineStyle=               answer{3};
            MeanTrace_LineWidth=       str2num(answer{4});
            SliceMeanTrace_LineStyle=          answer{5};
            SliceMeanTrace_LineWidth=  str2num(answer{6});
            clear answer
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            LowColorText=[];
            if ischar(ThreshLow_LineColor)
                LowColorText=ThreshLow_LineColor;
            else
                LowColorText=mat2str(ThreshLow_LineColor);
            end
            HighColorText=[];
            if ischar(ThreshHigh_LineColor)
                HighColorText=ThreshHigh_LineColor;
            else
                HighColorText=mat2str(ThreshHigh_LineColor);
            end
            MaskColorText=[];
            if ischar(ThreshMask_LineColor)
                MaskColorText=ThreshMask_LineColor;
            else
                MaskColorText=mat2str(ThreshMask_LineColor);
            end
            FrameColorText=[];
            if ischar(Frame_LineColor)
                FrameColorText=Frame_LineColor;
            else
                FrameColorText=mat2str(Frame_LineColor);
            end
            prompt = {  'Threshold Line Style',...
                        'Threshold Line Width',...
                        'Frame Marker Line Style',...
                        'Frame Marker Line Width',...
                        'ThreshLow_LineColor (letter or [r,g,b] 0-1)',...
                        'ThreshHigh_LineColor (letter or [r,g,b] 0-1)',...
                        'ThreshMask_LineColor (letter or [r,g,b] 0-1)',...
                        'Frame_LineColor (letter or [r,g,b] 0-1)',...
                        };
            dlg_title = 'Trace/Hist Marker Format';
            num_lines = 1;
            def = {         Thresh_LineStyle,...
                    num2str(Thresh_LineWidth)...
                            Frame_LineStyle,...
                    num2str(Frame_LineWidth)...
                            LowColorText,...
                            HighColorText,...
                            MaskColorText,...
                            FrameColorText,...
                    };
            answer = inputdlg(prompt,dlg_title,num_lines,def);
            Thresh_LineStyle=               answer{1};
            Thresh_LineWidth=       str2num(answer{2});
            Frame_LineStyle=                answer{3};
            Frame_LineWidth=        str2num(answer{4});
            if any(strfind(answer{5},'['))
                ThreshLow_LineColor=ConvertString2Array(answer{5});
            else
                ThreshLow_LineColor=answer{5};
            end
            if any(strfind(answer{6},'['))
                ThreshHigh_LineColor=ConvertString2Array(answer{6});
            else
                ThreshHigh_LineColor=answer{6};
            end
            if any(strfind(answer{7},'['))
                ThreshMask_LineColor=ConvertString2Array(answer{7});
            else
                ThreshMask_LineColor=answer{7};
            end
            if any(strfind(answer{8},'['))
                Frame_LineColor=ConvertString2Array(answer{8});
            else
                Frame_LineColor=answer{8};
            end
            clear answer
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            HistDisplay(HistAxis,HistAxisPosition)
            TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(FormatTraces_Button, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
        function FormatFrameMarkers(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(FormatFrameMarkers_Button, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            for m=1:length(FrameMarkers)
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                ColorText=[];
                if ischar(FrameMarkers(m).Color)
                    ColorText=FrameMarkers(m).Color;
                else
                    ColorText=mat2str(FrameMarkers(m).Color);
                end
                prompt = {  FrameMarkers(m).Label,...
                            [FrameMarkers(m).Label,' MarkerTextOn (1/0)'],...
                            'FontSize',...
                            'Label X Offset (frame)',...
                            'Label Y Offset (frame)',...
                            'Label Horz. Align (left center right)',...
                            'Label Vert. Align (top middle bottom)',...
                            'Label Text Pre Persistence (#pre frames)',...
                            'Label Text Post Persistence (#post frames)',...
                            };
                dlg_title = ['Format for: ',FrameMarkers(m).Label];
                num_lines = 1;
                def = { FrameMarkers(m).Label,...
                        num2str(FrameMarkers(m).MarkerTextOn)...
                        num2str(FrameMarkers(m).FontSize)...
                        num2str(FrameMarkers(m).TextXOffset)...
                        num2str(FrameMarkers(m).TextYOffset)...
                        FrameMarkers(m).HorizontalAlignment,...
                        FrameMarkers(m).VerticalAlignment,...
                        num2str(FrameMarkers(m).LabelPersistence.PreFrames),...
                        num2str(FrameMarkers(m).LabelPersistence.PostFrames),...
                        };
                answer = inputdlg(prompt,dlg_title,num_lines,def);
                FrameMarkers(m).Label=                  answer{1};
                FrameMarkers(m).MarkerTextOn=   str2num(answer{2});
                FrameMarkers(m).FontSize=       str2num(answer{3});
                FrameMarkers(m).TextXOffset=    str2num(answer{4});
                FrameMarkers(m).TextYOffset=    str2num(answer{5});
                FrameMarkers(m).HorizontalAlignment=    answer{6};
                FrameMarkers(m).VerticalAlignment=      answer{7};
                FrameMarkers(m).LabelPersistence.PreFrames= str2num(answer{8});
                FrameMarkers(m).LabelPersistence.PostFrames= str2num(answer{9});
                clear answer

                prompt = {  [FrameMarkers(m).Label,' MarkerOn (1/0)'],...
                            'Style 1=vert 2=horz top 3=horz bottm',...
                            'FrameAdjust',...
                            'Color (letter or [r,g,b] 0-1)',...
                            'LineMarkerStyle (ex : or .-)',...
                            'LineWidth',...
                            'MarkerSize',...
                            };
                dlg_title = ['Format for: ',FrameMarkers(m).Label];
                num_lines = 1;
                def = { num2str(FrameMarkers(m).MarkerOn),...
                        num2str(FrameMarkers(m).Style),...
                        num2str(FrameMarkers(m).FrameAdjust),...
                        ColorText,...
                        FrameMarkers(m).LineMarkerStyle,...
                        num2str(FrameMarkers(m).LineWidth)...
                        num2str(FrameMarkers(m).MarkerSize)...
                        };
                answer = inputdlg(prompt,dlg_title,num_lines,def);
                FrameMarkers(m).MarkerOn=       str2num(answer{1});
                FrameMarkers(m).Style=          str2num(answer{2});
                FrameMarkers(m).FrameAdjust=    str2num(answer{3});
                if any(strfind(answer{4},'['))
                    FrameMarkers(m).Color=...
                                    ConvertString2Array(answer{4});
                else
                    FrameMarkers(m).Color=              answer{4};
                end
                FrameMarkers(m).LineMarkerStyle=        answer{5};
                FrameMarkers(m).LineWidth=      str2num(answer{6});
                FrameMarkers(m).MarkerSize=     str2num(answer{7});
                clear answer
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(FormatFrameMarkers_Button, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end                
        function FormatROIs(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(FormatROIs_Button, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            prompt = {'ROI Radius (px)',...
                'ROI Border Line Style',...
                'ROI Border Line Width'};
            dlg_title = 'ROI Format';
            num_lines = 1;
            def = { num2str(ROI_Marker_Radius_px),...
                    ROI_Border_LineStyle,...
                    num2str(ROI_Border_LineWidth)...
                    };
            answer = inputdlg(prompt,dlg_title,num_lines,def);
            ROI_Marker_Radius_px=           str2num(answer{1});
            ROI_Border_LineStyle=                   answer{2};
            ROI_Border_LineWidth=           str2num(answer{3});
            clear answer
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(FormatROIs_Button, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function AddPixelTrace(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(UpdateTrace_Pixel_Button, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if TileChannels||TileSlices||TileFrames
                WarningPopup = questdlg({'Please Exit Tiling Mode to Add Pixel Traces'},'Problem Encountered!','OK','OK');
            else
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                axes(ViewerImageAxis)
                Txt1=text(ZoomDataRegion_Props.BoundingBox(1)+ZoomDataRegion_Props.BoundingBox(3)*0.05,...
                    ZoomDataRegion_Props.BoundingBox(2)+ZoomDataRegion_Props.BoundingBox(4)*0.05,...
                    'Select ROI Center(s) <ENTER> when done','color','w','fontsize',16);
                drawnow
                [TempX,TempY] = ginput;
                NumROIs=length(ROIs);
                for i=1:size(TempX,1)
                    NumROIs=NumROIs+1;
                    ROIs(NumROIs).Type=1;
                    ROIs(NumROIs).Slice=Slice;
                    ROIs(NumROIs).Channel=Channel;
                    ROIs(NumROIs).Frame=Frame;
                    ROIs(NumROIs).Coord=round([TempX(i),TempY(i),Frame]);
                    [ROIs(NumROIs).TraceChannel]=ExtractTraces(ROIs(NumROIs).Type,ROIs(NumROIs).Coord,[],ROIs(NumROIs).Slice);
                end
                TempColors=varycolor(NumROIs);
                for ROI=1:NumROIs
                    ROIs(ROI).Color=TempColors(ROI,:);
                end
                axes(TracePlotAxis)
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                ROITraces=1;
                set(ROITraces_Button,'value',ROITraces);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %UpdateDisplay
                CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(UpdateTrace_Pixel_Button, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
        function AddROITrace(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(UpdateTrace_ROI_Button, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if TileChannels||TileSlices||TileFrames
                WarningPopup = questdlg({'Please Exit Tiling Mode to Add ROI Traces'},'Problem Encountered!','OK','OK');
            else
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                axes(ViewerImageAxis)
                Txt1=text(ZoomDataRegion_Props.BoundingBox(1)+ZoomDataRegion_Props.BoundingBox(3)*0.05,...
                    ZoomDataRegion_Props.BoundingBox(2)+ZoomDataRegion_Props.BoundingBox(4)*0.05,...
                    'Select ROIs (Empty ROI when done)','color','w','fontsize',16);
                drawnow
                NumROIs=length(ROIs);
                cont=1;
                Count=0;
                while cont
                    TempDataRegion=roipoly;
                    Count=Count+1;
                    TempBorders(Count).BorderLine=FindROIBorders(TempDataRegion,1);
                    hold on
                    for j=1:length(TempBorders(Count).BorderLine)
                        TempBorders(Count).P1=plot(TempBorders(Count).BorderLine{j}.BorderLine(:,2),...
                            TempBorders(Count).BorderLine{j}.BorderLine(:,1),...
                            ROI_Border_LineStyle,'color','w','linewidth',ROI_Border_LineWidth+1);
                        TempBorders(Count).P2=plot(TempBorders(Count).BorderLine{j}.BorderLine(:,2),...
                            TempBorders(Count).BorderLine{j}.BorderLine(:,1),...
                            ROI_Border_LineStyle,'color','r','linewidth',ROI_Border_LineWidth);
                    end
%                     if ~ReleaseFig
%                         uiwait(ViewerFig);
%                     end
                    if any(TempDataRegion(:))
                        NumROIs=NumROIs+1;
                        ROIs(NumROIs).Type=2;
                        ROIs(NumROIs).Slice=Slice;
                        ROIs(NumROIs).Channel=Channel;
                        ROIs(NumROIs).Frame=Frame;
                        ROIs(NumROIs).DataRegion=TempDataRegion;
                        [ROIs(NumROIs).BorderLine]=FindROIBorders(ROIs(NumROIs).DataRegion,1);
                        [ROIs(NumROIs).TraceChannel]=ExtractTraces(ROIs(NumROIs).Type,[],ROIs(NumROIs).DataRegion,ROIs(NumROIs).Slice);
                    else
                        cont=0;
                    end
                end
                delete(Txt1);
                TempColors=varycolor(NumROIs);
                for ROI=1:NumROIs
                    ROIs(ROI).Color=TempColors(ROI,:);
                end
                for Count=1:length(TempBorders)
                    delete(TempBorders(Count).P1);
                    delete(TempBorders(Count).P2);
                end
                axes(TracePlotAxis)
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                ROIBorders=1;
                set(ROIBorders_Button,'value',ROIBorders);
                ROITraces=1;
                set(ROITraces_Button,'value',ROITraces);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %UpdateDisplay
                CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(UpdateTrace_ROI_Button, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
        function UndoROI(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(UndoROI_Button, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            NumROIs=length(ROIs);
            if NumROIs>0
                warning(['Removing ROI #',num2str(NumROIs)]);
                ROIs(NumROIs)=[];
                NumROIs=length(ROIs);
            else
                warning('NO ROIs to Undo...')
            end

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(UndoROI_Button, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function [TraceChannel]=ExtractTraces(Type,Coord,DataRegion,Slice)
            for cc=1:Last_C
                TempTrace=[];
                TraceChannel(cc).Trace=[];
                for tt=1:Last_T
                    switch StackOrder
                        case 'YXT'
                            TempImage1=ImageArray(:,:,tt);
                        case 'YXZ'
                        case 'YXC'
                        case 'YXZT'
                            TempImage1=ImageArray(:,:,Slice,tt);
                        case 'YXTZ'
                            TempImage1=ImageArray(:,:,tt,Slice);
                        case 'YXTC'
                            TempImage1=ImageArray(:,:,tt,cc);
                        case 'YXCT'
                            TempImage1=ImageArray(:,:,cc,tt);
                        case 'YXZTC'
                            TempImage1=ImageArray(:,:,Slice,tt,cc);
                        case 'YXTZC'
                            TempImage1=ImageArray(:,:,tt,Slice,cc);
                        case 'YX[RGB]T'
                        case 'YXT[RGB]'
                    end
                    TempImage1=squeeze(TempImage1);
                    if Type==1
                        TempTrace(tt)=TempImage1(Coord(2),Coord(1));
                    else
                        TempTrace(tt)=nanmean(TempImage1(DataRegion));
                    end
%                         count=count+1;
%                         if any(count==[1:round((length(ROIs)*Last_T)/TextUpdateIntervals):(length(ROIs)*Last_T)])
%                             fprintf('.')
%                         end
%                     end
%                     ROIs(ROI).TraceChannel(cc).Trace=TempTrace;
                end
                TraceChannel(cc).Trace=TempTrace;
                clear TempTrace
            end
            TempMarkers=zeros(1,Last_T);
            for l=1:length(LocalizationMarkers)
                for ll=1:length(LocalizationMarkers(l).Markers)
                    TempCoord=round([LocalizationMarkers(l).Markers(ll).Y,LocalizationMarkers(l).Markers(ll).X]);
                    if DataRegion(TempCoord(1),TempCoord(2))==1
                        TempMarkers(LocalizationMarkers(l).Markers(ll).T)=l;
                    end 
                end
            end
            for cc=1:Last_C
                TraceChannel(cc).LocalizationMarkers=TempMarkers;
            end
            clear TempMarkers
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function SetColorMap(~,~,~)
            Channel_Info(Channel).DisplayColorMapIndex = get(ColorMapList,'Value');
            if Channel_Info(Channel).DisplayColorMapIndex<1||Channel_Info(Channel).DisplayColorMapIndex>length(ColorMapOptions)
                warning('Not possible')
            else
                set(ColorMapList, 'Enable', 'off');
                Channel_Info(Channel).DisplayColorMap=ColorMapOptions{Channel_Info(Channel).DisplayColorMapIndex};
                if Z_Projection&&~T_Projection
                    [   Channel_Info(Channel).Z_Projection_Data.ColorMaps.ColorMap,...
                        Channel_Info(Channel).Z_Projection_Data.ValueAdjust,...
                        Channel_Info(Channel).Z_Projection_Data.ContrastHigh,...
                        Channel_Info(Channel).Z_Projection_Data.ContrastLow]=...
                        StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                            Channel_Info(Channel).Z_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                elseif ~Z_Projection&&T_Projection
                    [   Channel_Info(Channel).T_Projection_Data.ColorMaps.ColorMap,...
                        Channel_Info(Channel).T_Projection_Data.ValueAdjust,...
                        Channel_Info(Channel).T_Projection_Data.ContrastHigh,...
                        Channel_Info(Channel).T_Projection_Data.ContrastLow]=...
                        StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                            Channel_Info(Channel).T_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                elseif Z_Projection&&T_Projection
                    error('Not Currently Possible')
                else
                    [   Channel_Info(Channel).ColorMap,...
                        Channel_Info(Channel).ValueAdjust,...
                        Channel_Info(Channel).ContrastHigh,...
                        Channel_Info(Channel).ContrastLow]=...
                        StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                            Channel_Info(Channel).Display_Limits,Channel_Info(Channel).ColorScalar);
                end
                ColorBarDisplay(ViewerFig,ColorBarAxis,ColorBarAxisPosition);
                HistDisplay(HistAxis,HistAxisPosition)
                if T_Stack
                    TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %UpdateDisplay
                CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                set(ColorMapList, 'Enable', 'on');
                set(ViewerFig,'CurrentObject',ViewerImageAxis)
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            end
        end
        function ChangeSpeed(~,~,~)
            FPS=str2num(get(FPS_Ctl,'String'));
            set(FPS_Ctl,'Value',FPS)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(FPSButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(FPSButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function Jump2Frame(~,~,~)
            Frame=str2num(get(FramePos,'String'));
            set(Frame_sld,'Value',Frame)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(FrameButton, 'Enable', 'off');
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if ~RGB_Stack
                if T_Stack
                    TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                end
                if LiveHist
                    HistDisplay(HistAxis,HistAxisPosition);
                end
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(FrameButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        function Jump2Slice(~,~,~)
            Slice=str2num(get(SlicePos,'String'));
            set(Slice_sld,'Value',Slice)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(SliceButton, 'Enable', 'off');
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if ~RGB_Stack
                if T_Stack
                    TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                end
                if LiveHist
                    HistDisplay(HistAxis,HistAxisPosition);
                end
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(SliceButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        function Jump2Channel(~,~,~)
            Channel=str2num(get(ChannelPos,'String'));
            CurrentTraceYData=Channel_Info(Channel).Overall_MeanValues;
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ChannelButton, 'Enable', 'off');
            %UpdateDisplay
            set(ColorMapList,'Value',Channel_Info(Channel).DisplayColorMapIndex);
            set(ChannelLabelText,'String',Channel_Labels{Channel});
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %SetColorMap;
            ColorBarDisplay(ViewerFig,ColorBarAxis,ColorBarAxisPosition);
            if Z_Projection&&~T_Projection
                set(LowDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(1)))
                set(HighDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)))
                warning off
                set(Low_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1))
                set(High_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                warning on
            elseif ~Z_Projection&&T_Projection
                set(LowDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(1)))
                set(HighDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(2)))
                warning off
                set(Low_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1))
                set(High_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                warning on
            elseif Z_Projection&&T_Projection
                error('Not Currently Possible')
            else
                set(LowDisp,'String',num2str(Channel_Info(Channel).Display_Limits(1)))
                set(HighDisp,'String',num2str(Channel_Info(Channel).Display_Limits(2)))
                warning off
                set(Low_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(1))
                set(High_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                warning on
            end
            warning on
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if ~RGB_Stack
                if T_Stack
                    TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                end
                if LiveHist
                    HistDisplay(HistAxis,HistAxisPosition);
                end
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ChannelButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function Frame_Slider(src,~,~)
            Frame = get(src,'Value');
            Frame=round(Frame);
            if Frame<1
                Frame=1;
            end
            if Frame>Last_T
                Frame=Last_T;
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if ~RGB_Stack
                if T_Stack
                    TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                end
                if LiveHist
                    HistDisplay(HistAxis,HistAxisPosition);
                end
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(Frame_sld, 'Enable', 'off');
            set(FramePos,'String',num2str(Frame))
            set(Frame_sld, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        function Slice_Slider(src,~,~)
            Slice = get(src,'Value');
            Slice=round(Slice);
            if Slice<1
                Slice=1;
            end
            if Slice>Last_Z
                Slice=Last_Z;
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if ~RGB_Stack
                if T_Stack
                    TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                end
                if LiveHist
                    HistDisplay(HistAxis,HistAxisPosition);
                end
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(Slice_sld, 'Enable', 'off');
            set(SlicePos,'String',num2str(Slice))
            set(Slice_sld, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        function Channel_Slider(src,~,~)
            Channel = get(src,'Value');
            Channel=round(Channel);
            if Channel<1
                Channel=1;
            end
            if Channel>Last_C
                Channel=Last_C;
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            if Channel_Info(Channel).DisplayColorMapIndex~=0
                set(ColorMapList,'Value',Channel_Info(Channel).DisplayColorMapIndex);
            end
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %SetColorMap;
            ColorBarDisplay(ViewerFig,ColorBarAxis,ColorBarAxisPosition);
            if Z_Projection&&~T_Projection
                set(LowDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(1)))
                set(HighDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)))
                warning off
                set(Low_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1))
                set(High_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                warning on
            elseif ~Z_Projection&&T_Projection
                set(LowDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(1)))
                set(HighDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(2)))
                warning off
                set(Low_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1))
                set(High_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                warning on
            elseif Z_Projection&&T_Projection
                error('Not Currently Possible')
            else
                set(LowDisp,'String',num2str(Channel_Info(Channel).Display_Limits(1)))
                set(HighDisp,'String',num2str(Channel_Info(Channel).Display_Limits(2)))
                warning off
                set(Low_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(1))
                set(High_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                warning on
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if ~RGB_Stack
                if T_Stack
                    TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                end
                if LiveHist
                    HistDisplay(HistAxis,HistAxisPosition);
                end
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(Channel_sld, 'Enable', 'off');
            set(ChannelPos,'String',num2str(Channel))
            set(ChannelLabelText,'String',Channel_Labels{Channel});
            set(Channel_sld, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function StartPlayStack(PlayButton,~,~)
            BufferViewerImageAxes=horzcat(BufferViewerImageAxes,{ViewerImageAxis});
            BufferMaskAxes=horzcat(BufferMaskAxes,MaskAxes);
            BufferTileAxes=horzcat(BufferTileAxes,TileAxes);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            figure(ViewerFig)
            PlayBack=1;
            set(PlayButton,'value',PlayBack)
            set(PauseButton,'value',~PlayBack)
            set(PlayButton,'enable','off')
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            while PlayBack
                if T_Stack
                    if Frame==Last_T
                        Frame=1;
                    else
                        Frame=Frame+1;
                    end
                    set(Frame_sld,'Value',Frame)
                    set(FramePos,'String',num2str(Frame))
                elseif Z_Stack&&~T_Stack
                    if Slice==Last_Z
                        Slice=1;
                    else
                        Slice=Slice+1;
                    end
                    set(Slice_sld,'Value',Slice)
                    set(SlicePos,'String',num2str(Slice))
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %UpdateDisplay
                CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                pause(1/FPS)
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(PlayButton,'enable','on')
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        function PausePlayStack(PauseButton,~,~)
            figure(ViewerFig)
            PlayBack=0;
            set(PlayButton,'value',PlayBack)
            set(PauseButton,'value',~PlayBack)
            set(PauseButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(PauseButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function ZoomIn(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            ZoomOn=1;
            set(ZoomInButton,'Value',ZoomOn);    
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ZoomInButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            try
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                if TileChannels||TileSlices||TileFrames
                    TileOptions=[];
                    for i=1:length(TileAxes)
                        TileOptions{i}=num2str(i);
                    end
                    [ZoomSelectAxisIndex, ~] = listdlg('PromptString',{'Select Panel'},...
                        'SelectionMode','single','ListString',TileOptions,'ListSize', [200 200]);
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                ZoomMethod = questdlg({'Zoom Method?'},'Zoom Method?!','Custom','Define',ZoomMethod);
                switch ZoomMethod
                    case 'Custom'
                        if TileChannels||TileSlices||TileFrames
                            axes(TileAxes{ZoomSelectAxisIndex});
                            Txt1=text(ZoomDataRegion_Props.BoundingBox(1)+ZoomDataRegion_Props.BoundingBox(3)*0.05,...
                                ZoomDataRegion_Props.BoundingBox(2)+ZoomDataRegion_Props.BoundingBox(4)*0.05,...
                                'Select Zoom Area','color','w','fontsize',16);
                            drawnow
                        else
                            axes(ViewerImageAxis)
                            Txt1=text(ZoomDataRegion_Props.BoundingBox(1)+ZoomDataRegion_Props.BoundingBox(3)*0.05,...
                                ZoomDataRegion_Props.BoundingBox(2)+ZoomDataRegion_Props.BoundingBox(4)*0.05,...
                                'Select Zoom Area','color','w','fontsize',16);
                            drawnow
                        end
                        ZoomDataRegion = roipoly;
                        ZoomDataRegion_Props = regionprops(double(ZoomDataRegion), 'BoundingBox');clear ZoomDataRegion

                        delete(Txt1);
                    case 'Define'
                        if ~isfield(ZoomDataRegion_Props,'ZoomHeight')
                            ZoomDataRegion_Props.ZoomHeight=ImageHeight;
                            ZoomDataRegion_Props.ZoomWidth=ImageWidth;
                        end
                        TestingZoomBox=1;
                        while TestingZoomBox
                            prompt = {  'Zoom Box Height (px)',...
                                        'Zoom Box Width (px)',...
                                        };
                            dlg_title = ['Define Zoom Parameters'];
                            num_lines = 1;
                            def = { num2str(ZoomDataRegion_Props.ZoomHeight)...
                                    num2str(ZoomDataRegion_Props.ZoomWidth)...
                                    };
                            answer = inputdlg(prompt,dlg_title,num_lines,def);
                                    ZoomDataRegion_Props.ZoomHeight=    str2num(answer{1});
                                    ZoomDataRegion_Props.ZoomWidth=     str2num(answer{2});
                            if ZoomDataRegion_Props.ZoomHeight<=ImageHeight&&ZoomDataRegion_Props.ZoomWidth<=ImageWidth
                                TestingZoomBox=0;
                            else
                                warning on
                                warning('Zoom Box TOO BIG! try again!')
                            end
                        end
                        
                        if TileChannels||TileSlices||TileFrames
                            axes(TileAxes{ZoomSelectAxisIndex});
                            Txt1=text(ZoomDataRegion_Props.BoundingBox(1)+ZoomDataRegion_Props.BoundingBox(3)*0.05,...
                                ZoomDataRegion_Props.BoundingBox(2)+ZoomDataRegion_Props.BoundingBox(4)*0.05,...
                                'Select Zoom ROI Center','color','w','fontsize',16);
                            drawnow
                        else
                            axes(ViewerImageAxis)
                            Txt1=text(ZoomDataRegion_Props.BoundingBox(1)+ZoomDataRegion_Props.BoundingBox(3)*0.05,...
                                ZoomDataRegion_Props.BoundingBox(2)+ZoomDataRegion_Props.BoundingBox(4)*0.05,...
                                'Select Zoom ROI Center','color','w','fontsize',16);
                            drawnow
                        end
                        drawnow
                        [TempX,TempY] = ginput(1);
                        
                        delete(Txt1)
                        ZoomDataRegion_Props.BoundingBox(1)=round(TempX)-floor(ZoomDataRegion_Props.ZoomWidth/2)-0.5;
                        ZoomDataRegion_Props.BoundingBox(2)=round(TempY)-floor(ZoomDataRegion_Props.ZoomHeight/2)-0.5;
                        ZoomDataRegion_Props.BoundingBox(3)=ZoomDataRegion_Props.ZoomWidth-1;
                        ZoomDataRegion_Props.BoundingBox(4)=ZoomDataRegion_Props.ZoomHeight-1;
                        
                        if ZoomDataRegion_Props.BoundingBox(1)<1
                            XAdjust=abs(ZoomDataRegion_Props.BoundingBox(1))+1;
                            warning(['Adjusting X Position of Zoom Box by ',num2str(XAdjust),' px'])
                            ZoomDataRegion_Props.BoundingBox(1)=ZoomDataRegion_Props.BoundingBox(1)+XAdjust;
                        end
                        if ZoomDataRegion_Props.BoundingBox(2)<1
                            YAdjust=abs(ZoomDataRegion_Props.BoundingBox(2))+1;
                            warning(['Adjusting Y Position of Zoom Box by ',num2str(YAdjust),' px'])
                            ZoomDataRegion_Props.BoundingBox(2)=ZoomDataRegion_Props.BoundingBox(2)+YAdjust;
                        end
                        if ZoomDataRegion_Props.BoundingBox(1)+ZoomDataRegion_Props.BoundingBox(3)>ImageWidth
                            XAdjust=(ZoomDataRegion_Props.BoundingBox(1)+ZoomDataRegion_Props.BoundingBox(3))-ImageWidth;
                            warning(['Adjusting X Position of Zoom Box by ',num2str(XAdjust),' px'])
                            ZoomDataRegion_Props.BoundingBox(1)=ZoomDataRegion_Props.BoundingBox(1)-XAdjust;
                        end
                        if ZoomDataRegion_Props.BoundingBox(2)+ZoomDataRegion_Props.BoundingBox(4)>ImageHeight
                            YAdjust=(ZoomDataRegion_Props.BoundingBox(2)+ZoomDataRegion_Props.BoundingBox(4))-ImageHeight;
                            warning(['Adjusting Y Position of Zoom Box by ',num2str(YAdjust),' px'])
                            ZoomDataRegion_Props.BoundingBox(2)=ZoomDataRegion_Props.BoundingBox(2)-YAdjust;
                        end
                end
                %ZoomDataRegion_Props.BoundingBox
                %[ZoomDataRegion_Props.BoundingBox(2),ZoomDataRegion_Props.BoundingBox(2)+ZoomDataRegion_Props.BoundingBox(4)+1]
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                if isempty(ZoomDataRegion_Props.BoundingBox)
                    ZoomOn=0;
                    ZoomReset
                else
                    if ScaleBarOn
                        set(ScaleBarButton,'value',1)
                        AddScaleBar
                    end
                    if ImageLabelOn
                       set(ImageLabelButton,'value',1)
                       AddImageLabel
                    end
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            catch
                ZoomOn=0;
                WarningPopup = questdlg({'Unable to complete Zoom!'},'Problem Encountered!','OK','OK');
                ZoomReset
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ZoomInButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
        function ZoomReset(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
               PausePlayStack(PauseButton);
            end
            ZoomOn=0;
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ZoomInButton,'Value',ZoomOn);    
            set(ZoomResetButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            try
                if TileChannels||TileSlices||TileFrames
                    for i=1:length(TileAxes)
                        delete(TileAxes{i})
                    end
                else
                    axes(ViewerImageAxis);
                end
                ZoomDataRegion_Props.BoundingBox=[1,1,ImageHeight,ImageWidth];
                ZoomScaleBar=[];
                if ScaleBarOn
                    set(ScaleBarButton,'value',1)
                    AddScaleBar
                end
                if ImageLabelOn
                   set(ImageLabelButton,'value',1)
                   AddImageLabel
                end
            catch
                ZoomOn=0;
                WarningPopup = questdlg({'Unable to Rest Zoom!'},'Problem Encountered!','OK','OK');
                ZoomReset
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ZoomResetButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function CropData(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
               PausePlayStack(PauseButton);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(CropDataButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            warning('Not ready yet!')
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(CropDataButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
        function ReorientData(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
               PausePlayStack(PauseButton);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ReorientDataButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            warning('Not ready yet!')
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ReorientDataButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function FlagFrame(~,~,~)
            set(FlagFrameButton, 'Enable', 'off');
            if Tracker_T_Data(Frame,1)
                Tracker_T_Data(Frame,:)=0;
            else
                Tracker_T_Data(Frame,:)=1;
            end
            if Tracker_Z_Data(Slice,1)
                Tracker_Z_Data(Slice,:)=0;
            else
                Tracker_Z_Data(Slice,:)=1;
            end
            if isempty(TrackerFig)
                TrackerFig=figure('position',TrackerFigPosition,'name',[SaveName,' FLAGS']);
            else
                figure(TrackerFig)
                if T_Stack
                    cla(Tracker_T_Axis,'reset')
                end
                if Z_Stack
                    cla(Tracker_Z_Axis,'reset')
                end
            end
            if T_Stack
                Tracker_T_Axis=subplot(1,2,1);
                imagesc(Tracker_T_Data)
                set(Tracker_T_Axis,'ydir','reverse','ytick',[1:size(Tracker_T_Data,1)])
                set(Tracker_T_Axis,'xtick',[])
                caxis([0,1])
                colormap(Tracker_T_Axis,'gray');
                %axis equal tight
                ylabel('Frames')
            end
            if Z_Stack
                Tracker_Z_Axis=subplot(1,2,2);
                imagesc(Tracker_Z_Data)
                set(Tracker_Z_Axis,'ydir','reverse','ytick',[1:size(Tracker_Z_Data,1)])
                set(Tracker_Z_Axis,'xtick',[])
                caxis([0,1])
                colormap(Tracker_Z_Axis,'gray');
                %axis equal tight
                ylabel('Slices')
            end
            figure(ViewerFig);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            figure(ViewerFig);
            set(FlagFrameButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function AddLocalization(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(AddLocalizationButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if TileChannels||TileSlices||TileFrames
                WarningPopup = questdlg({'Please Exit Tiling Mode to Add Location(s)'},'Problem Encountered!','OK','OK');
            else
                axes(ViewerImageAxis)
                Txt1=text(ZoomDataRegion_Props.BoundingBox(1)+ZoomDataRegion_Props.BoundingBox(3)*0.05,...
                    ZoomDataRegion_Props.BoundingBox(2)+ZoomDataRegion_Props.BoundingBox(4)*0.05,...
                    'Select Location(s) <ENTER> when done','color','w','fontsize',16);
                drawnow
                [TempX,TempY] = ginput;
                for i=1:size(TempX,1)
                    ii=length(LocalizationMarkers(CurrentLocalizationType).Markers)+1;
                    LocalizationMarkers(CurrentLocalizationType).Markers(ii).X=...
                        TempX(i);
                    LocalizationMarkers(CurrentLocalizationType).Markers(ii).Y=...
                        TempY(i);
                    LocalizationMarkers(CurrentLocalizationType).Markers(ii).T=...
                        Frame;
                    LocalizationMarkers(CurrentLocalizationType).Markers(ii).Z=...
                        Slice;
                end
                delete(Txt1)
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %UpdateDisplay
                CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(AddLocalizationButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
        function DeleteLocalization(~,~,~)
            warning('Not Ready Yet')
            warning('Not Ready Yet')
            warning('Not Ready Yet')
            warning('Not Ready Yet')
            warning('Not Ready Yet')
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(DeleteLocalizationButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            axes(ViewerImageAxis)
            Txt1=text(ZoomDataRegion_Props.BoundingBox(1)+ZoomDataRegion_Props.BoundingBox(3)*0.05,...
                ZoomDataRegion_Props.BoundingBox(2)+ZoomDataRegion_Props.BoundingBox(4)*0.05,...
                'Select Location(s) <ENTER> when done','color','w','fontsize',16);
            drawnow
            [TempX,TempY] = ginput;
            for i=1:size(TempX,1)
                TempIndices=[];
                TempDists=[];
                for ii=1:length(LocalizationMarkers(CurrentLocalizationType).Markers)
                    if LocalizationMarkers(CurrentLocalizationType).Markers(ii).T==Frame&&...
                        LocalizationMarkers(CurrentLocalizationType).Markers(ii).Z==Slice
                        TempIndices=[TempIndices,ii];
                        TempDists=[TempDists,...
                            sqrt((LocalizationMarkers(CurrentLocalizationType).Markers(ii).X-TempX(i))^2+...
                            (LocalizationMarkers(CurrentLocalizationType).Markers(ii).Y-TempY(i))^2)];
                    end
                end
                if ~isempty(TempIndices)
                    [~,DeleteIndex]=min(abs(TempDists));
                    LocalizationMarkers(CurrentLocalizationType).Markers(TempIndices(DeleteIndex))=[];
                end
            end
            delete(Txt1)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(DeleteLocalizationButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
        function UndoLocalization(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(UndoLocalizationButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if ~isempty(LocalizationMarkers(CurrentLocalizationType).Markers)
                LocalizationMarkers(CurrentLocalizationType).Markers=...
                    LocalizationMarkers(CurrentLocalizationType).Markers(1:length(LocalizationMarkers(CurrentLocalizationType).Markers)-1);
            else
               warning('Nothing to undo in this localizaiton type') 
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(UndoLocalizationButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
        function SetLocalizaitonType(~,~,~)
            warning('Not Ready Yet')
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            CurrentLocalizationType=get(LocalizationTypeList,'value');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(LocalizationTypeList, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if CurrentLocalizationType==length(LocalzationTypes)
                warning('Adding a new localizaiton type...')
                m=length(LocalizationMarkers)+1;

                LocalizationMarkers(m).Label='New';
                LocalizationMarkers(m).Labels='';
                LocalizationMarkers(m).MarkerTextOn=0;
                LocalizationMarkers(m).FontSize=6;
                LocalizationMarkers(m).TextXOffset=0;
                LocalizationMarkers(m).TextYOffset=0;
                LocalizationMarkers(m).HorizontalAlignment='left';
                LocalizationMarkers(m).VerticalAlignment='middle';
                LocalizationMarkers(m).MarkerOn=1;
                LocalizationMarkers(m).Style=1;
                LocalizationMarkers(m).Radius_px=0;
                LocalizationMarkers(m).Color='m';
                LocalizationMarkers(m).LineMarkerStyle='o';
                LocalizationMarkers(m).LineWidth=0.5;
                LocalizationMarkers(m).MarkerSize=6;
                LocalizationMarkers(m).Markers=[];
                SetLocalizationMarkerFormat(m)
                
                LocalzationTypes=[];
                for l=1:length(LocalizationMarkers)
                    LocalzationTypes{l}=LocalizationMarkers(l).Label;
                end
                LocalzationTypes{length(LocalizationMarkers)+1}='ADD';
                CurrentLocalizationType=m;
                set(LocalizationTypeList,'value',CurrentLocalizationType);

            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(LocalizationTypeList, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
        function ToggleLocalization(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            LocalizationMarkersOn=get(DisplayLocalizationButton,'value');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(DisplayLocalizationButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(DisplayLocalizationButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
        function FormatLocalizationMarkers(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(FormatLocalizationMarkersButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            SetLocalizationMarkerFormat(CurrentLocalizationType)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(FormatLocalizationMarkersButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end   
        function SetLocalizationMarkerFormat(m)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            ColorText=[];
            if ischar(LocalizationMarkers(m).Color)
                ColorText=LocalizationMarkers(m).Color;
            else
                ColorText=mat2str(LocalizationMarkers(m).Color);
            end
            prompt = {  LocalizationMarkers(m).Label,...
                        'Individual Label prefix',...
                        [LocalizationMarkers(m).Label,' MarkerTextOn (1/0)'],...
                        'FontSize',...
                        'Label X Offset (frame)',...
                        'Label Y Offset (frame)',...
                        'Label Horz. Align (left center right)',...
                        'Label Vert. Align (top middle bottom)',...
                        };
            dlg_title = ['Format for: ',LocalizationMarkers(m).Label];
            num_lines = 1;
            def = { LocalizationMarkers(m).Label,...
                    LocalizationMarkers(m).Labels,...
                    num2str(LocalizationMarkers(m).MarkerTextOn)...
                    num2str(LocalizationMarkers(m).FontSize)...
                    num2str(LocalizationMarkers(m).TextXOffset)...
                    num2str(LocalizationMarkers(m).TextYOffset)...
                    LocalizationMarkers(m).HorizontalAlignment,...
                    LocalizationMarkers(m).VerticalAlignment,...
                    };
            answer = inputdlg(prompt,dlg_title,num_lines,def);
            LocalizationMarkers(m).Label=                  answer{1};
            LocalizationMarkers(m).Labels=                 answer{2};
            LocalizationMarkers(m).MarkerTextOn=   str2num(answer{3});
            LocalizationMarkers(m).FontSize=       str2num(answer{4});
            LocalizationMarkers(m).TextXOffset=    str2num(answer{5});
            LocalizationMarkers(m).TextYOffset=    str2num(answer{6});
            LocalizationMarkers(m).HorizontalAlignment=    answer{7};
            LocalizationMarkers(m).VerticalAlignment=      answer{8};
            clear answer
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            prompt = {  [LocalizationMarkers(m).Label,' MarkerOn (1/0)'],...
                        'Style 1=marker ONLY 2=circle (Adjust LineMarkerStyle)',...
                        'Radius ONLY if Style=2 (px)',...
                        'Persistence Pre Frames',...
                        'Persistence post Frames',...
                        'Color (letter or [r,g,b] 0-1)',...
                        'LineMarkerStyle (ex : or .- or o)',...
                        'LineWidth',...
                        'MarkerSize',...
                        };
            dlg_title = ['Format for: ',LocalizationMarkers(m).Label];
            num_lines = 1;
            def = { num2str(LocalizationMarkers(m).MarkerOn),...
                    num2str(LocalizationMarkers(m).Style),...
                    num2str(LocalizationMarkers(m).Radius_px),...
                    num2str(LocalizationMarkers(m).LabelPersistence.PreFrames),...
                    num2str(LocalizationMarkers(m).LabelPersistence.PostFrames),...
                    ColorText,...
                    LocalizationMarkers(m).LineMarkerStyle,...
                    num2str(LocalizationMarkers(m).LineWidth)...
                    num2str(LocalizationMarkers(m).MarkerSize)...
                    };
            answer = inputdlg(prompt,dlg_title,num_lines,def);
            LocalizationMarkers(m).MarkerOn=       str2num(answer{1});
            LocalizationMarkers(m).Style=          str2num(answer{2});
            LocalizationMarkers(m).Radius_px=      str2num(answer{3});
            LocalizationMarkers(m).LabelPersistence.PreFrames=str2num(answer{4});
            LocalizationMarkers(m).LabelPersistence.PostFrames=str2num(answer{5});
            if any(strfind(answer{6},'['))
                LocalizationMarkers(m).Color=...
                                ConvertString2Array(answer{6});
            else
                LocalizationMarkers(m).Color=              answer{6};
            end
            LocalizationMarkers(m).LineMarkerStyle=        answer{7};
            LocalizationMarkers(m).LineWidth=      str2num(answer{8});
            LocalizationMarkers(m).MarkerSize=     str2num(answer{9});
            clear answer
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function AddProfile(~,~,~)
            warning('Not Ready Yet')
            set(AddProfileButton, 'Enable', 'off');
%             ProfileInfo(1).Coord=ginput_w(1);
%             ProfileInfo(2).Coord=ginput_w(1);
%             hold on
%             plot([ProfileInfo(1).Coord(1),ProfileInfo(2).Coord(1)],...
%                  [ProfileInfo(1).Coord(2),ProfileInfo(2).Coord(2)],...
%                  ':','color','w');

             
             
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(AddProfileButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function PlayMovie(~,~,~)
            warning('Not Ready Yet')
            set(PlayMovieButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            try
                [MovieName,MovieDir]=uigetfile({'*.avi', 'All SUPPORTED MOVIE Files (*.avi)'});
                Stack_Viewer_AVI_Player(MovieName,MovieDir); 
            catch
                WarningPopup = questdlg({'Unable to play movie!'},'Problem Encountered!','OK','OK');
                ZoomReset
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(PlayMovieButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function AddMask(~,~,~)
            MaskOn = get(MaskButton,'Value');    
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            set(MaskButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if MaskOn
                CurrentDataRegionMaskStatus=DataRegionMaskOn;
                if DataRegionMaskOn
                   warning('Turning off Region Masking For Mask Overlay')
                   DataRegionMaskOn=0;
                   set(DataRegionMaskButton,'Value',DataRegionMaskOn);
                end
                CurrentMergeChannelStatus=MergeChannel;
                if MergeChannel
                    warning('Turning off Channel Merge For Mask Overlay')
                    MergeChannel=0;
                    set(MergeChannelButton,'Value',MergeChannel);
                end
                for cc=1:Last_C
                    ColorText=[];
                    if ischar(Channel_Info(cc).MaskColor)
                        ColorText=Channel_Info(cc).MaskColor;
                    else
                        ColorText=mat2str(Channel_Info(cc).MaskColor);
                    end
                    prompt = {[Channel_Labels{cc},' Mask Cutoff'],'Mask Alpha','Mask Color (letter or [r,g,b] 0-1)','Invert Mask (1/0)'};
                    dlg_title = [Channel_Labels{cc},' Mask'];
                    num_lines = 1;
                    def = {num2str(Channel_Info(cc).MaskLim),...
                        num2str(Channel_Info(cc).MaskAlpha),...
                        ColorText,...
                        num2str(Channel_Info(cc).MaskInvert)};
                    answer = inputdlg(prompt,dlg_title,num_lines,def);
                    Channel_Info(cc).MaskLim=str2num(answer{1});
                    Channel_Info(cc).MaskAlpha=str2num(answer{2});
                    if any(strfind(answer{3},'['))
                        Channel_Info(cc).MaskColor=ConvertString2Array(answer{3});
                    else
                        Channel_Info(cc).MaskColor=answer{3};
                    end
                    Channel_Info(cc).MaskInvert=str2num(answer{4});
                    clear answer;
                    Channel_Info(cc).MaskColorMap=vertcat(ColorDefinitionsLookup(Channel_Info(cc).MaskColor),[0,0,0]);
                end
            else
                if CurrentDataRegionMaskStatus
                   DataRegionMaskOn=1;
                   set(DataRegionMaskButton,'Value',DataRegionMaskOn);
                end
                if CurrentMergeChannelStatus
                    MergeChannel=1;
                    set(MergeChannelButton,'Value',MergeChannel);
                end
                figure(ViewerFig)
                axes(ViewerImageAxis)
                if ~isempty(MaskAxes)
                    if isfield(MaskAxes,'ForegroundAxis')
                        MaskAxes=rmfield(MaskAxes,'ForegroundAxis');
                    end
                    for i=1:length(MaskAxes)
                        %if isvalid(MaskAxes{i})
                            delete(MaskAxes{i})
                        %end
                    end
                end
                MaskAxes=[];
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if ~RGB_Stack
                HistDisplay(HistAxis,HistAxisPosition)
                if T_Stack
                    TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                end
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(MaskButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function AddScaleBar(~,~,~)
            ScaleBarOn = get(ScaleBarButton,'Value');    
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            set(ScaleBarButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            try
                if ScaleBarOn
                    if isempty(ImagingInfo)
                        CollectImagingInfo
                    end
                    if ZoomOn
                        if isempty(ZoomScaleBar)
                            ZoomScaleBar.Length=ceil(ZoomDataRegion_Props.BoundingBox(3)*ImagingInfo.PixelSize*0.1);
                            ZoomScaleBar.TextOn=1;
                            ZoomScaleBar.Unit=ImagingInfo.PixelUnit;
                            ZoomScaleBar.FontSize=14;
                            ZoomScaleBar.LineColor='w';
                            ZoomScaleBar.LineWidth=0.5;
                            ZoomScaleBar.Position='BL';
                            ZoomScaleBar.HorzCornerAdjust=0.025;
                            ZoomScaleBar.VertCornerAdjust=0.05;
                            ZoomScaleBar.Length_px=ZoomScaleBar.Length/ImagingInfo.PixelSize;
                            ZoomScaleBar.XData=[];
                            ZoomScaleBar.YData=[];
                        end
                        if ~isfield(ZoomScaleBar,'TextOn')
                            ZoomScaleBar.TextOn=1;
                        end
                        ColorText=[];
                        if ischar(ZoomScaleBar.LineColor)
                            ColorText=ZoomScaleBar.LineColor;
                        else
                            ColorText=mat2str(ZoomScaleBar.LineColor);
                        end
                        prompt = {'Length','Text On (1/0)','Unit {ex. um nm)','FontSize','LineColor (letter or [r,g,b] 0-1)','LineWidth','Position (BL BR TL TR)','HorzCornerAdjust (0-1)','VertCornerAdjust (0-1)'};
                        dlg_title = 'Zoom ScaleBar';
                        num_lines = 1;
                        def = {num2str(ZoomScaleBar.Length),num2str(ZoomScaleBar.TextOn),ZoomScaleBar.Unit,num2str(ZoomScaleBar.FontSize),ColorText,num2str(ZoomScaleBar.LineWidth),ZoomScaleBar.Position,num2str(ZoomScaleBar.HorzCornerAdjust),num2str(ZoomScaleBar.VertCornerAdjust)};
                        answer = inputdlg(prompt,dlg_title,num_lines,def);
                        ZoomScaleBar.Length=         str2num(answer{1});
                        ZoomScaleBar.TextOn=         str2num(answer{2});
                        ZoomScaleBar.Unit=                   answer{3};
                        ZoomScaleBar.FontSize=       str2num(answer{4});
                        if any(strfind(answer{5},'['))
                            ZoomScaleBar.LineColor=ConvertString2Array(answer{5});
                        else
                            ZoomScaleBar.LineColor=answer{5};
                        end
                        ZoomScaleBar.LineWidth=      str2num(answer{6});
                        ZoomScaleBar.Position=               answer{7};
                        ZoomScaleBar.HorzCornerAdjust=str2num(answer{8});
                        ZoomScaleBar.VertCornerAdjust=str2num(answer{9});
                        ZoomScaleBar.Length_px=ZoomScaleBar.Length/ImagingInfo.PixelSize;
                        switch ZoomScaleBar.Position
                            case 'BL'
                                ZoomScaleBar.XData=ZoomDataRegion_Props.BoundingBox(1)+[ceil(ZoomDataRegion_Props.BoundingBox(3)*ZoomScaleBar.HorzCornerAdjust),ceil(ZoomDataRegion_Props.BoundingBox(3)*ZoomScaleBar.HorzCornerAdjust)+ZoomScaleBar.Length_px];
                                ZoomScaleBar.YData=ZoomDataRegion_Props.BoundingBox(2)+[ceil(ZoomDataRegion_Props.BoundingBox(4)*(1-ZoomScaleBar.VertCornerAdjust)),ceil(ZoomDataRegion_Props.BoundingBox(4)*(1-ZoomScaleBar.VertCornerAdjust))];
                            case 'BR'
                                ZoomScaleBar.XData=ZoomDataRegion_Props.BoundingBox(1)+[ceil(ZoomDataRegion_Props.BoundingBox(3)*(1-ZoomScaleBar.HorzCornerAdjust))-ZoomScaleBar.Length_px,ceil(ZoomDataRegion_Props.BoundingBox(3)*(1-ZoomScaleBar.HorzCornerAdjust))];
                                ZoomScaleBar.YData=ZoomDataRegion_Props.BoundingBox(2)+[ceil(ZoomDataRegion_Props.BoundingBox(4)*(1-ZoomScaleBar.VertCornerAdjust)),ceil(ZoomDataRegion_Props.BoundingBox(4)*(1-ZoomScaleBar.VertCornerAdjust))];
                            case 'TL'
                                ZoomScaleBar.XData=ZoomDataRegion_Props.BoundingBox(1)+[ceil(ZoomDataRegion_Props.BoundingBox(3)*ZoomScaleBar.HorzCornerAdjust),ceil(ZoomDataRegion_Props.BoundingBox(3)*ZoomScaleBar.HorzCornerAdjust)+ZoomScaleBar.Length_px];
                                ZoomScaleBar.YData=ZoomDataRegion_Props.BoundingBox(2)+[ceil(ZoomDataRegion_Props.BoundingBox(4)*ZoomScaleBar.VertCornerAdjust),ceil(ZoomDataRegion_Props.BoundingBox(4)*ZoomScaleBar.VertCornerAdjust)];
                            case 'TR'
                                ZoomScaleBar.XData=ZoomDataRegion_Props.BoundingBox(1)+[ceil(ZoomDataRegion_Props.BoundingBox(3)*(1-ZoomScaleBar.HorzCornerAdjust))-ZoomScaleBar.Length_px,ceil(ZoomDataRegion_Props.BoundingBox(3)*(1-ZoomScaleBar.HorzCornerAdjust))];
                                ZoomScaleBar.YData=ZoomDataRegion_Props.BoundingBox(2)+[ceil(ZoomDataRegion_Props.BoundingBox(4)*ZoomScaleBar.VertCornerAdjust),ceil(ZoomDataRegion_Props.BoundingBox(4)*ZoomScaleBar.VertCornerAdjust)];
                        end
                        clear answer
                    else
                        if isempty(ScaleBar)
                            ScaleBar.Length=ceil(ImageWidth*ImagingInfo.PixelSize*0.1);
                            ScaleBar.TextOn=1;
                            ScaleBar.Unit=ImagingInfo.PixelUnit;
                            ScaleBar.FontSize=14;
                            ScaleBar.LineColor='w';
                            ScaleBar.LineWidth=0.5;
                            ScaleBar.Position='BL';
                            ScaleBar.HorzCornerAdjust=0.025;
                            ScaleBar.VertCornerAdjust=0.05;
                            ScaleBar.Length_px=ScaleBar.Length/ImagingInfo.PixelSize;
                            ScaleBar.XData=[];
                            ScaleBar.YData=[];
                        end
                        if ~isfield(ScaleBar,'TextOn')
                            ScaleBar.TextOn=1;
                        end
                        ColorText=[];
                        if ischar(ScaleBar.LineColor)
                            ColorText=ScaleBar.LineColor;
                        else
                            ColorText=mat2str(ScaleBar.LineColor);
                        end
                        prompt = {'Length','Text On (1/0)','Unit {ex. um nm)','FontSize','LineColor (letter or [r,g,b] 0-1)','LineWidth','Position (BL BR TL TR)','HorzCornerAdjust (0-1)','VertCornerAdjust (0-1)'};
                        dlg_title = 'Scalebar';
                        num_lines = 1;
                        def = {num2str(ScaleBar.Length),num2str(ScaleBar.TextOn),ScaleBar.Unit,num2str(ScaleBar.FontSize),ColorText,num2str(ScaleBar.LineWidth),ScaleBar.Position,num2str(ScaleBar.HorzCornerAdjust),num2str(ScaleBar.VertCornerAdjust)};
                        answer = inputdlg(prompt,dlg_title,num_lines,def);
                        ScaleBar.Length=         str2num(answer{1});
                        ScaleBar.TextOn=         str2num(answer{2});
                        ScaleBar.Unit=                   answer{3};
                        ScaleBar.FontSize=       str2num(answer{4});
                        if any(strfind(answer{5},'['))
                            ScaleBar.LineColor=ConvertString2Array(answer{5});
                        else
                            ScaleBar.LineColor=answer{5};
                        end
                        ScaleBar.LineWidth=      str2num(answer{6});
                        ScaleBar.Position=               answer{7};
                        ScaleBar.HorzCornerAdjust=str2num(answer{8});
                        ScaleBar.VertCornerAdjust=str2num(answer{9});
                        ScaleBar.Length_px=ScaleBar.Length/ImagingInfo.PixelSize;
                        switch ScaleBar.Position
                            case 'BL'
                                ScaleBar.XData=[ceil(ImageWidth*ScaleBar.HorzCornerAdjust),ceil(ImageWidth*ScaleBar.HorzCornerAdjust)+ScaleBar.Length_px];
                                ScaleBar.YData=[ceil(ImageHeight*(1-ScaleBar.VertCornerAdjust)),ceil(ImageHeight*(1-ScaleBar.VertCornerAdjust))];
                            case 'BR'
                                ScaleBar.XData=[ceil(ImageWidth*(1-ScaleBar.HorzCornerAdjust))-ScaleBar.Length_px,ceil(ImageWidth*(1-ScaleBar.HorzCornerAdjust))];
                                ScaleBar.YData=[ceil(ImageHeight*(1-ScaleBar.VertCornerAdjust)),ceil(ImageHeight*(1-ScaleBar.VertCornerAdjust))];
                            case 'TL'
                                ScaleBar.XData=[ceil(ImageWidth*ScaleBar.HorzCornerAdjust),ceil(ImageWidth*ScaleBar.HorzCornerAdjust)+ScaleBar.Length_px];
                                ScaleBar.YData=[ceil(ImageHeight*ScaleBar.VertCornerAdjust),ceil(ImageHeight*ScaleBar.VertCornerAdjust)];
                            case 'TR'
                                ScaleBar.XData=[ceil(ImageWidth*(1-ScaleBar.HorzCornerAdjust))-ScaleBar.Length_px,ceil(ImageWidth*(1-ScaleBar.HorzCornerAdjust))];
                                ScaleBar.YData=[ceil(ImageHeight*ScaleBar.VertCornerAdjust),ceil(ImageHeight*ScaleBar.VertCornerAdjust)];
                        end
                        clear answer
                    end            
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %if ~ZoomOn
                    %UpdateDisplay
                    CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                    [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
                %end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            catch
                ScaleBarOn=0;
                set(ScaleBarButton,'Value',ScaleBarOn);    
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ScaleBarButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function AddImageLabel(~,~,~)
            ImageLabelOn = get(ImageLabelButton,'Value');    
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ImageLabelButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            try
                if ImageLabelOn
                    if isempty(ImagingInfo)
                        CollectImagingInfo
                    end
                    if ZoomOn
                        if isempty(ZoomImageLabel)
                            ZoomImageLabel.FontSize=14;
                            ZoomImageLabel.Position='TR';
                            ZoomImageLabel.HorizontalAlignment='right';
                            ZoomImageLabel.VerticalAlignment='top';
                            ZoomImageLabel.HorzCornerAdjust=0.025;
                            ZoomImageLabel.VertCornerAdjust=0.025;
                            ZoomImageLabel.IncludeC=C_Stack;
                            ZoomImageLabel.IncludeZ=Z_Stack;
                            ZoomImageLabel.ZStyle=2;
                            ZoomImageLabel.IncludeT=T_Stack;
                            ZoomImageLabel.TStyle=2;
                        end
                        prompt = {'FontSize','Position (BL BC BR TL TC TR)',...
                            'Horz Align (left center right)','Vert Align (top middle bottom)',...
                            'HorzCornerAdjust (0-1)','VertCornerAdjust (0-1)',...
                            'Include C (1/0)',...
                            'Include Z (1/0)',...
                            'Z Style(0 Both,1 Z=,2 um/nm)',...
                            'Include T (1/0)',...
                            'T Style(0 Both,1 T=,2 s/ms)'};
                        dlg_title = 'ZoomImageLabel';
                        num_lines = 1;
                        def = {num2str(ZoomImageLabel.FontSize),ZoomImageLabel.Position,...
                            ZoomImageLabel.HorizontalAlignment,ZoomImageLabel.VerticalAlignment,...
                            num2str(ZoomImageLabel.HorzCornerAdjust),num2str(ZoomImageLabel.VertCornerAdjust),...
                            num2str(ZoomImageLabel.IncludeC),...
                            num2str(ZoomImageLabel.IncludeZ),num2str(ZoomImageLabel.ZStyle),...
                            num2str(ZoomImageLabel.IncludeT),num2str(ZoomImageLabel.TStyle)};
                        answer = inputdlg(prompt,dlg_title,num_lines,def);
                        ZoomImageLabel.FontSize=        str2num(answer{1});
                        ZoomImageLabel.Position=                answer{2};
                        ZoomImageLabel.HorizontalAlignment=     answer{3};
                        ZoomImageLabel.VerticalAlignment=       answer{4};
                        ZoomImageLabel.HorzCornerAdjust=str2num(answer{5});
                        ZoomImageLabel.VertCornerAdjust=str2num(answer{6});
                        ZoomImageLabel.IncludeC=        str2num(answer{7});
                        ZoomImageLabel.IncludeZ=        str2num(answer{8});
                        ZoomImageLabel.ZStyle=          str2num(answer{9});
                        ZoomImageLabel.IncludeT=        str2num(answer{10});
                        ZoomImageLabel.TStyle=          str2num(answer{11});
                        switch ZoomImageLabel.Position
                            case 'BL'
                                ZoomImageLabel.XData=ZoomDataRegion_Props.BoundingBox(1)+[ceil(ZoomDataRegion_Props.BoundingBox(3)*ZoomImageLabel.HorzCornerAdjust)];
                                ZoomImageLabel.YData=ZoomDataRegion_Props.BoundingBox(2)+[ceil(ZoomDataRegion_Props.BoundingBox(4)*(1-ZoomImageLabel.VertCornerAdjust))];
                            case 'BC'
                                ZoomImageLabel.XData=ZoomDataRegion_Props.BoundingBox(1)+[round(ZoomDataRegion_Props.BoundingBox(3)/2)];
                                ZoomImageLabel.YData=ZoomDataRegion_Props.BoundingBox(2)+[ceil(ZoomDataRegion_Props.BoundingBox(4)*(1-ZoomImageLabel.VertCornerAdjust))];
                            case 'BR'
                                ZoomImageLabel.XData=ZoomDataRegion_Props.BoundingBox(1)+[ceil(ZoomDataRegion_Props.BoundingBox(3)*(1-ZoomImageLabel.HorzCornerAdjust))];
                                ZoomImageLabel.YData=ZoomDataRegion_Props.BoundingBox(2)+[ceil(ZoomDataRegion_Props.BoundingBox(4)*(1-ZoomImageLabel.VertCornerAdjust))];
                            case 'TL'
                                ZoomImageLabel.XData=ZoomDataRegion_Props.BoundingBox(1)+[ceil(ZoomDataRegion_Props.BoundingBox(3)*ZoomImageLabel.HorzCornerAdjust)];
                                ZoomImageLabel.YData=ZoomDataRegion_Props.BoundingBox(2)+[ceil(ZoomDataRegion_Props.BoundingBox(4)*ZoomImageLabel.VertCornerAdjust)];
                            case 'TC'
                                ZoomImageLabel.XData=ZoomDataRegion_Props.BoundingBox(1)+[round(ZoomDataRegion_Props.BoundingBox(3)/2)];
                                ZoomImageLabel.YData=ZoomDataRegion_Props.BoundingBox(2)+[ceil(ZoomDataRegion_Props.BoundingBox(4)*ZoomImageLabel.VertCornerAdjust)];
                            case 'TR'
                                ZoomImageLabel.XData=ZoomDataRegion_Props.BoundingBox(1)+[ceil(ZoomDataRegion_Props.BoundingBox(3)*(1-ZoomImageLabel.HorzCornerAdjust))];
                                ZoomImageLabel.YData=ZoomDataRegion_Props.BoundingBox(2)+[ceil(ZoomDataRegion_Props.BoundingBox(4)*ZoomImageLabel.VertCornerAdjust)];
                        end
                        clear answer
                    else
                        if isempty(ImageLabel)
                            ImageLabel.FontSize=14;
                            ImageLabel.Position='TR';
                            ImageLabel.HorizontalAlignment='right';
                            ImageLabel.VerticalAlignment='top';
                            ImageLabel.HorzCornerAdjust=0.025;
                            ImageLabel.VertCornerAdjust=0.025;
                            ImageLabel.IncludeC=C_Stack;
                            ImageLabel.IncludeZ=Z_Stack;
                            ImageLabel.ZStyle=2;
                            ImageLabel.IncludeT=T_Stack;
                            ImageLabel.TStyle=2;
                        end
                        prompt = {'FontSize','Position (BL BC BR TL TC TR)',...
                            'Horz Align (left center right)','Vert Align (top middle bottom)',...
                            'HorzCornerAdjust (0-1)','VertCornerAdjust (0-1)',...
                            'Include C (1/0)',...
                            'Include Z (1/0)',...
                            'Z Style(0 Both,1 Z=,2 um/nm)',...
                            'Include T (1/0)',...
                            'T Style(0 Both,1 T=,2 s/ms)'};
                        dlg_title = 'ImageLabel';
                        num_lines = 1;
                        def = {num2str(ImageLabel.FontSize),ImageLabel.Position,...
                            ImageLabel.HorizontalAlignment,ImageLabel.VerticalAlignment,...
                            num2str(ImageLabel.HorzCornerAdjust),num2str(ImageLabel.VertCornerAdjust),...
                            num2str(ImageLabel.IncludeC),...
                            num2str(ImageLabel.IncludeZ),num2str(ImageLabel.ZStyle),...
                            num2str(ImageLabel.IncludeT),num2str(ImageLabel.TStyle)};
                        answer = inputdlg(prompt,dlg_title,num_lines,def);
                        ImageLabel.FontSize=        str2num(answer{1});
                        ImageLabel.Position=                answer{2};
                        ImageLabel.HorizontalAlignment=     answer{3};
                        ImageLabel.VerticalAlignment=       answer{4};
                        ImageLabel.HorzCornerAdjust=str2num(answer{5});
                        ImageLabel.VertCornerAdjust=str2num(answer{6});
                        ImageLabel.IncludeC=        str2num(answer{7});
                        ImageLabel.IncludeZ=        str2num(answer{8});
                        ImageLabel.ZStyle=          str2num(answer{9});
                        ImageLabel.IncludeT=        str2num(answer{10});
                        ImageLabel.TStyle=          str2num(answer{11});
                        switch ImageLabel.Position
                            case 'BL'
                                ImageLabel.XData=[ceil(ImageWidth*ImageLabel.HorzCornerAdjust)];
                                ImageLabel.YData=[ceil(ImageHeight*(1-ImageLabel.VertCornerAdjust))];
                            case 'BC'
                                ImageLabel.XData=[round(ImageWidth/2)];
                                ImageLabel.YData=[ceil(ImageHeight*(1-ImageLabel.VertCornerAdjust))];
                            case 'BR'
                                ImageLabel.XData=[ceil(ImageWidth*(1-ImageLabel.HorzCornerAdjust))];
                                ImageLabel.YData=[ceil(ImageHeight*(1-ImageLabel.VertCornerAdjust))];
                            case 'TL'
                                ImageLabel.XData=[ceil(ImageWidth*ImageLabel.HorzCornerAdjust)];
                                ImageLabel.YData=[ceil(ImageHeight*ImageLabel.VertCornerAdjust)];
                            case 'TC'
                                ImageLabel.XData=[round(ImageWidth/2)];
                                ImageLabel.YData=[ceil(ImageHeight*ImageLabel.VertCornerAdjust)];
                            case 'TR'
                                ImageLabel.XData=[ceil(ImageWidth*(1-ImageLabel.HorzCornerAdjust))];
                                ImageLabel.YData=[ceil(ImageHeight*ImageLabel.VertCornerAdjust)];
                        end
                        clear answer

                    end
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %UpdateDisplay
                CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            catch
                warning('Problem adding image label overlay...') 
                ImageLabelOn=0;
                set(ImageLabelButton,'Value',ImageLabelOn);    
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ImageLabelButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function AddColorBarOverlay(~,~,~)
            ColorBarOverlayOn = get(ColorBarOverlayButton,'Value');    
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ColorBarOverlayButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            ColorBarOverlay.ZoomOn=ZoomOn;
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            try
                if ColorBarOverlayOn
                    if ~isfield(ColorBarOverlay,'XData')
                        ColorBarOverlay.Orientation='Vertical';
                        ColorBarOverlay.LineWidth=0.5;
                        ColorBarOverlay.FontSize=14;
                        ColorBarOverlay.Color='w';
                        ColorBarOverlay.XData=[];
                        ColorBarOverlay.YData=[];
                        NewColorBarOverlay=1;
                    else
                        if ColorBarOverlay.ZoomOn~=ZoomOn
                            NewColorBarOverlay=1;
                        else
                            NewColorBarOverlayChoice = questdlg({'Reuse Existing ColorBar Overlay??'},'Reuse Existing ColorBar Overlay?','Reuse','New','Reuse');
                            switch NewColorBarOverlayChoice
                                case 'Reuse'
                                    NewColorBarOverlay=0;
                                case 'New'
                                    NewColorBarOverlay=1;
                            end
                        end
                    end
                    if NewColorBarOverlay
                        
                        TempChannel=Channel;
                        TempMergeChannel=MergeChannel;
                        if TempMergeChannel
                            ColorBarOverlayOn=0;
                            MergeChannel=0;
                            Channel=1;
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                            ColorBarOverlayOn=1;
                        end
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        ColorBarOverlay.Orientation = questdlg({'ColorBar Overlay Direction?'},'ColorBarOverlay?','Horizontal','Vertical',ColorBarOverlay.Orientation);
                        if ~isfield(ColorBarOverlay,'TextOffsetScalar')
                            switch ColorBarOverlay.Orientation
                                case 'Horizontal'
                                    ColorBarOverlay.TextOffsetScalar=0;
                                case 'Vertical'
                                    ColorBarOverlay.TextOffsetScalar=0.02;
                            end
                        end
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        ColorText=[];
                        if ischar(ColorBarOverlay.Color)
                            ColorText=ColorBarOverlay.Color;
                        else
                            ColorText=mat2str(ColorBarOverlay.Color);
                        end                        
                        prompt = {'LineWidth','FontSize','Label/Line Color(letter or [r,g,b] 0-1)','TextOffsetScalar'};
                        dlg_title = 'ColorBarOverlay';
                        num_lines = 1;
                        def = {num2str(ColorBarOverlay.LineWidth),num2str(ColorBarOverlay.FontSize),ColorText,...
                            num2str(ColorBarOverlay.TextOffsetScalar)};
                        answer = inputdlg(prompt,dlg_title,num_lines,def);
                        ColorBarOverlay.LineWidth=       str2num(answer{1});
                        ColorBarOverlay.FontSize=       str2num(answer{2});
                        if any(strfind(answer{3},'['))
                            ColorBarOverlay.Color=ConvertString2Array(answer{3});
                        else
                            ColorBarOverlay.Color=answer{3};
                        end
                        ColorBarOverlay.TextOffsetScalar=   str2num(answer{4});
                        clear answer
                        count=0;
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        figure(ViewerFig);
                        axes(ViewerImageAxis);
                        hold on
                        Txt1=text(ZoomDataRegion_Props.BoundingBox(1)+ZoomDataRegion_Props.BoundingBox(3)*0.05,...
                            ZoomDataRegion_Props.BoundingBox(2)+ZoomDataRegion_Props.BoundingBox(4)*0.05,...
                            'Add UpperLeft Corner','color','w','fontsize',16);
                        drawnow
                        ColorBarOverlay.UpperLeftCorner=ginput(1);
                        delete(Txt1)
                        ColorBarOverlay.UpperLeftCorner=round(ColorBarOverlay.UpperLeftCorner);
                        hold on
                        count=count+1;
                        TempPlot(count)=plot(ColorBarOverlay.UpperLeftCorner(1),ColorBarOverlay.UpperLeftCorner(2),...
                            '*-','color',ColorBarOverlay.Color,'linewidth',2,'markersize',12);
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        Txt1=text(ZoomDataRegion_Props.BoundingBox(1)+ZoomDataRegion_Props.BoundingBox(3)*0.05,...
                            ZoomDataRegion_Props.BoundingBox(2)+ZoomDataRegion_Props.BoundingBox(4)*0.05,...
                            'Add UpperRight Corner','color','w','fontsize',16);
                        drawnow
                        ColorBarOverlay.UpperRightCorner=ginput(1);
                        delete(Txt1)
                        ColorBarOverlay.UpperRightCorner=round(ColorBarOverlay.UpperRightCorner);
                        hold on
                        count=count+1;
                        TempPlot(count)=plot([ColorBarOverlay.UpperLeftCorner(1),ColorBarOverlay.UpperRightCorner(1)],...
                            [ColorBarOverlay.UpperLeftCorner(2),ColorBarOverlay.UpperLeftCorner(2)],...
                            '*-','color',ColorBarOverlay.Color,'linewidth',2,'markersize',12);
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        Txt1=text(ZoomDataRegion_Props.BoundingBox(1)+ZoomDataRegion_Props.BoundingBox(3)*0.05,...
                            ZoomDataRegion_Props.BoundingBox(2)+ZoomDataRegion_Props.BoundingBox(4)*0.05,...
                            'Add Bottom Edge','color','w','fontsize',16);
                        drawnow
                        ColorBarOverlay.LowerCorners=ginput(1);
                        delete(Txt1)
                        ColorBarOverlay.LowerCorners=round(ColorBarOverlay.LowerCorners);
                        count=count+1;
                        TempPlot(count)=plot([ColorBarOverlay.UpperLeftCorner(1),ColorBarOverlay.UpperLeftCorner(1)],...
                            [ColorBarOverlay.UpperLeftCorner(2),ColorBarOverlay.LowerCorners(2)],...
                            '*-','color',ColorBarOverlay.Color,'linewidth',2,'markersize',12);
                        count=count+1;
                        TempPlot(count)=plot([ColorBarOverlay.UpperRightCorner(1),ColorBarOverlay.UpperRightCorner(1)],...
                            [ColorBarOverlay.UpperLeftCorner(2),ColorBarOverlay.LowerCorners(2)],...
                            '*-','color',ColorBarOverlay.Color,'linewidth',2,'markersize',12);
                        count=count+1;
                        TempPlot(count)=plot([ColorBarOverlay.UpperLeftCorner(1),ColorBarOverlay.UpperRightCorner(1)],...
                            [ColorBarOverlay.LowerCorners(2),ColorBarOverlay.LowerCorners(2)],...
                            '*-','color',ColorBarOverlay.Color,'linewidth',2,'markersize',12);
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        ColorBarOverlay.XData=[ColorBarOverlay.UpperLeftCorner(1):ColorBarOverlay.UpperRightCorner(1)];
                        ColorBarOverlay.YData=[ColorBarOverlay.UpperLeftCorner(2):ColorBarOverlay.LowerCorners(2)];
                        switch ColorBarOverlay.Orientation
                            case 'Horizontal'
                                ColorBarOverlay.NumColors=length(ColorBarOverlay.XData);
                                ColorBarOverlay.LowText_XData=min(ColorBarOverlay.XData)-round(ImageWidth*ColorBarOverlay.TextOffsetScalar);
                                ColorBarOverlay.LowText_YData=mean(ColorBarOverlay.YData);
                                ColorBarOverlay.LowText_HorzAlign='right';
                                ColorBarOverlay.LowText_VertAlign='middle';
                                ColorBarOverlay.HighText_XData=max(ColorBarOverlay.XData)+round(ImageWidth*ColorBarOverlay.TextOffsetScalar);
                                ColorBarOverlay.HighText_YData=mean(ColorBarOverlay.YData);
                                ColorBarOverlay.HighText_HorzAlign='left';
                                ColorBarOverlay.HighText_VertAlign='middle';
                            case 'Vertical'
                                ColorBarOverlay.NumColors=length(ColorBarOverlay.YData);
                                ColorBarOverlay.LowText_XData=mean(ColorBarOverlay.XData);
                                ColorBarOverlay.LowText_YData=max(ColorBarOverlay.YData)+round(ImageHeight*ColorBarOverlay.TextOffsetScalar);
                                ColorBarOverlay.LowText_HorzAlign='center';
                                ColorBarOverlay.LowText_VertAlign='top';
                                ColorBarOverlay.HighText_XData=mean(ColorBarOverlay.XData);
                                ColorBarOverlay.HighText_YData=min(ColorBarOverlay.YData)-round(ImageHeight*ColorBarOverlay.TextOffsetScalar);
                                ColorBarOverlay.HighText_HorzAlign='center';
                                ColorBarOverlay.HighText_VertAlign='bottom';
                        end
                        ColorBarOverlay.Border(1).XData=[ColorBarOverlay.XData(1)-0.5,ColorBarOverlay.XData(length(ColorBarOverlay.XData))+0.5];
                        ColorBarOverlay.Border(1).YData=[ColorBarOverlay.YData(1)-0.5,ColorBarOverlay.YData(1)-0.5];
                        ColorBarOverlay.Border(2).XData=[ColorBarOverlay.XData(1)-0.5,ColorBarOverlay.XData(length(ColorBarOverlay.XData))+0.5];
                        ColorBarOverlay.Border(2).YData=[ColorBarOverlay.YData(length(ColorBarOverlay.YData))+0.5,ColorBarOverlay.YData(length(ColorBarOverlay.YData))+0.5];
                        ColorBarOverlay.Border(3).XData=[ColorBarOverlay.XData(1)-0.5,ColorBarOverlay.XData(1)-0.5];
                        ColorBarOverlay.Border(3).YData=[ColorBarOverlay.YData(1)-0.5,ColorBarOverlay.YData(length(ColorBarOverlay.YData))+0.5];
                        ColorBarOverlay.Border(4).XData=[ColorBarOverlay.XData(length(ColorBarOverlay.XData))+0.5,ColorBarOverlay.XData(length(ColorBarOverlay.XData))+0.5];
                        ColorBarOverlay.Border(4).YData=[ColorBarOverlay.YData(1)-0.5,ColorBarOverlay.YData(length(ColorBarOverlay.YData))+0.5];
                        switch ColorBarOverlay.Orientation
                            case 'Horizontal'
                                ColorBarOverlay.LowText_Pre='';
                                ColorBarOverlay.LowText_Post='  ';
                                ColorBarOverlay.HighText_Pre='  ';
                                ColorBarOverlay.HighText_Post='';
                            case 'Vertical'
                                ColorBarOverlay.LowText_Pre='';
                                ColorBarOverlay.LowText_Post='';
                                ColorBarOverlay.HighText_Pre='';
                                ColorBarOverlay.HighText_Post='';
                        end
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        if TempMergeChannel
                            MergeChannel=TempMergeChannel;
                            Channel=TempChannel;
                        end
                    end
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            catch
                warning('Problem adding colorbar overlay...') 
                ColorBarOverlayOn=0;
                set(ColorBarOverlayButton,'Value',ColorBarOverlayOn);    
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ColorBarOverlayButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function ChannelLabelUpdate(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ChannelButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            for cc=1:Last_C
                prompt{cc} = ['Channel ',num2str(cc)];
                def{cc}=Channel_Labels{cc};
            end
            dlg_title = 'Channel_Labels';
            num_lines = 1;
            answer = inputdlg(prompt,dlg_title,num_lines,def);
            for cc=1:Last_C
                Channel_Labels{cc}=answer{cc};
            end
            clear answer
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ChannelButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function DataRegionBorder(~,~,~)
            DataRegionBorderOn = get(DataRegionBorderButton,'Value');    
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(DataRegionBorderButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(DataRegionBorderButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
        function DataRegionMask(~,~,~)
            DataRegionMaskOn = get(DataRegionMaskButton,'Value');    
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(DataRegionMaskButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(DataRegionMaskButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
        function DataRegionMaskFormat(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            set(DataRegionMaskFormatButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if DataRegionMaskOn||DataRegionBorderOn
                    prompt = {'DataRegionMask R','DataRegionMask G','DataRegionMask B','Border Color (ex w r g)','Border Line Style','Border Line Width'};
                    dlg_title = 'Scalebar';
                    num_lines = 1;
                    def = { num2str(DataRegionMaskColor(1)),...
                            num2str(DataRegionMaskColor(2))...
                            num2str(DataRegionMaskColor(3))...
                            BorderColor,...
                            BorderLineStyle,...
                            num2str(BorderWidth)};
                    answer = inputdlg(prompt,dlg_title,num_lines,def);
                    DataRegionMaskColor(1)=         str2num(answer{1});
                    DataRegionMaskColor(2)=         str2num(answer{2});
                    DataRegionMaskColor(3)=         str2num(answer{3});
                    BorderColor=                answer{4};
                    BorderLineStyle=            answer{5};
                    BorderWidth=                str2num(answer{6});
                    clear answer
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(DataRegionMaskFormatButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function UpdateLiveHist(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            if exist('AllPixelHist')
                if ~isempty(AllPixelHist)
                    delete(AllPixelHist)
                end
            end
            if exist('LiveHistTrace')
                if ~isempty(LiveHistTrace)
                    delete(LiveHistTrace)
                end
            end
            LiveHist=get(LiveHistButton,'value');
            NormHist=get(NormHistButton,'value');
            OverallHist=get(OverallHistButton,'value');
            SliceHist=get(SliceHistButton,'value');

%             if NormHist&&LiveHist
%                 OverallHist=0;
%                 set(OverallHistButton,'value',OverallHist)
%             end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(LiveHistButton, 'Enable', 'off');
            set(NormHistButton, 'Enable', 'off');
            set(OverallHistButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if ~RGB_Stack
                HistDisplay(HistAxis,HistAxisPosition)
                if T_Stack
                    TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                end
            end
            set(LiveHistButton, 'Enable', 'on');
            set(NormHistButton, 'Enable', 'on');
            set(OverallHistButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
        function UpdateHistDisplay(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            if exist('AllPixelHist')
                if ~isempty(AllPixelHist)
                    delete(AllPixelHist)
                end
            end
            if exist('LiveHistTrace')
                if ~isempty(LiveHistTrace)
                    delete(LiveHistTrace)
                end
            end
            AutoScaleHist=get(AutoScaleButton,'value');
            LogHistX=get(LogXButton,'value');
            LogHistY=get(LogYButton,'value');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(LogXButton, 'Enable', 'off');
            set(LogYButton, 'Enable', 'off');
            set(AutoScaleButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if ~RGB_Stack
                HistDisplay(HistAxis,HistAxisPosition)
                if T_Stack
                    TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                end
            end
            set(LogXButton, 'Enable', 'on');
            set(LogYButton, 'Enable', 'on');
            set(AutoScaleButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function HighLowContrast(src,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            TempLow = get(Low_sld,'Value');
            TempHigh = get(High_sld,'Value');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(LowButton, 'Enable', 'off');
            set(HighButton, 'Enable', 'off');
            set(Low_sld, 'Enable', 'off');
            set(High_sld, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if MergeChannel
                if Z_Projection&&~T_Projection
                    if TempLow~=Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1)
                        Z_Projection_ContrastAdjusted=1;
                        Merge_ContrastAdjusted=1;
                    end
                elseif ~Z_Projection&&T_Projection
                    if TempLow~=Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1)
                        T_Projection_ContrastAdjusted=1;
                        Merge_ContrastAdjusted=1;
                    end
                elseif Z_Projection&&T_Projection
                    error('Not Currently Possible')
                else
                    if TempLow~=Channel_Info(Channel).Normalized_Display_Limits(1)
                        Merge_ContrastAdjusted=1;
                    end
                end
            else
                if Z_Projection&&~T_Projection
                    if TempLow~=Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1)
                        Z_Projection_ContrastAdjusted=1;
                        Merge_ContrastAdjusted=1;
                    end
                elseif ~Z_Projection&&T_Projection
                    if TempLow~=Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1)
                        T_Projection_ContrastAdjusted=1;
                        Merge_ContrastAdjusted=1;
                    end
                elseif Z_Projection&&T_Projection
                    error('Not Currently Possible')
                else
                    if TempLow~=Channel_Info(Channel).Normalized_Display_Limits(1)
                        Merge_ContrastAdjusted=1;
                    end
                end
            end            
            if MergeChannel
                if Z_Projection&&~T_Projection
                    if TempHigh~=Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)
                        Z_Projection_ContrastAdjusted=1;
                        Merge_ContrastAdjusted=1;
                    end
                elseif ~Z_Projection&&T_Projection
                    if TempHigh~=Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)
                        T_Projection_ContrastAdjusted=1;
                        Merge_ContrastAdjusted=1;
                    end
                elseif Z_Projection&&T_Projection
                    error('Not Currently Possible')
                else
                    if TempHigh~=Channel_Info(Channel).Normalized_Display_Limits(2)
                        Merge_ContrastAdjusted=1;
                    end
                end
            else
                if Z_Projection&&~T_Projection
                    if TempHigh~=Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)
                        Z_Projection_ContrastAdjusted=1;
                        Merge_ContrastAdjusted=1;
                    end
                elseif ~Z_Projection&&T_Projection
                    if TempHigh~=Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)
                        T_Projection_ContrastAdjusted=1;
                        Merge_ContrastAdjusted=1;
                    end
                elseif Z_Projection&&T_Projection
                    error('Not Currently Possible')
                else
                    if TempHigh~=Channel_Info(Channel).Normalized_Display_Limits(2)
                        Merge_ContrastAdjusted=1;
                    end
                end
            end
            if MergeChannel
                if Z_Projection&&~T_Projection
                    if TempHigh<=Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1)
                        warning('Not possible')
                        set(src,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                    elseif Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)<=TempLow
                        warning('Not possible')
                        set(src,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1))
                    else
                        Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1)=TempLow;
                        Channel_Info(Channel).Z_Projection_Data.Display_Limits(1)=Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)=TempHigh;
                        Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)=Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).Z_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).Z_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Z_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(LowDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(1)))
                        warning off
                        set(Low_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)))
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                        Merge_Z_Projection
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                elseif ~Z_Projection&&T_Projection
                    if TempHigh<=Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1)
                        warning('Not possible')
                        set(src,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                    elseif Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)<=TempLow
                        warning('Not possible')
                        set(src,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1))
                    else
                        Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1)=TempLow;
                        Channel_Info(Channel).T_Projection_Data.Display_Limits(1)=Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)=TempHigh;
                        Channel_Info(Channel).T_Projection_Data.Display_Limits(2)=Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).T_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).T_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).T_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).T_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).T_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(LowDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(1)))
                        warning off
                        set(Low_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(2)))
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                        Merge_T_Projection
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                elseif Z_Projection&&T_Projection
                    error('Not Currently Possible')
                else
                    if TempHigh<=Channel_Info(Channel).Normalized_Display_Limits(1)
                        warning('Not possible')
                        set(src,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                    elseif Channel_Info(Channel).Normalized_Display_Limits(2)<=TempLow
                        warning('Not possible')
                        set(src,'Value',Channel_Info(Channel).Normalized_Display_Limits(1))
                    else
                        Channel_Info(Channel).Normalized_Display_Limits(1)=TempLow;
                        Channel_Info(Channel).Display_Limits(1)=Channel_Info(Channel).Normalized_Display_Limits(1)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        Channel_Info(Channel).Normalized_Display_Limits(2)=TempHigh;
                        Channel_Info(Channel).Display_Limits(2)=Channel_Info(Channel).Normalized_Display_Limits(2)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).ColorMap,...
                            Channel_Info(Channel).ValueAdjust,...
                            Channel_Info(Channel).ContrastHigh,...
                            Channel_Info(Channel).ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(LowDisp,'String',num2str(Channel_Info(Channel).Display_Limits(1)))
                        warning off
                        set(Low_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(1))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Display_Limits(2)))
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                        warning on
                        Merge_Channels
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                   end
                end
            else
                if Z_Projection&&~T_Projection
                    if TempHigh<=Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1)
                        warning('Not possible')
                        set(src,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                    elseif Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)<=TempLow
                        warning('Not possible')
                        set(src,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1))
                    else
                        Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1)=TempLow;
                        Channel_Info(Channel).Z_Projection_Data.Display_Limits(1)=Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)=TempHigh;
                        Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)=Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).Z_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).Z_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Z_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(LowDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(1)))
                        warning off
                        set(Low_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)))
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                elseif ~Z_Projection&&T_Projection
                    if TempHigh<=Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1)
                        warning('Not possible')
                        set(src,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                    elseif Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)<=TempLow
                        warning('Not possible')
                        set(src,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1))
                    else
                        Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1)=TempLow;
                        Channel_Info(Channel).T_Projection_Data.Display_Limits(1)=Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)=TempHigh;
                        Channel_Info(Channel).T_Projection_Data.Display_Limits(2)=Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).T_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).T_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).T_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).T_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).T_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(LowDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(1)))
                        warning off
                        set(Low_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(2)))
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                elseif Z_Projection&&T_Projection
                    error('Not Currently Possible')
                else
                    if TempHigh<=Channel_Info(Channel).Normalized_Display_Limits(1)
                        warning('Not possible')
                        set(src,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                    elseif Channel_Info(Channel).Normalized_Display_Limits(2)<=TempLow
                        warning('Not possible')
                        set(src,'Value',Channel_Info(Channel).Normalized_Display_Limits(1))
                    else
                        Channel_Info(Channel).Normalized_Display_Limits(1)=TempLow;
                        Channel_Info(Channel).Display_Limits(1)=Channel_Info(Channel).Normalized_Display_Limits(1)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        Channel_Info(Channel).Normalized_Display_Limits(2)=TempHigh;
                        Channel_Info(Channel).Display_Limits(2)=Channel_Info(Channel).Normalized_Display_Limits(2)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).ColorMap,...
                            Channel_Info(Channel).ValueAdjust,...
                            Channel_Info(Channel).ContrastHigh,...
                            Channel_Info(Channel).ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(LowDisp,'String',num2str(Channel_Info(Channel).Display_Limits(1)))
                        warning off
                        set(Low_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(1))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Display_Limits(2)))
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                        warning on
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                end
            end
            clear TempHigh
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(LowButton, 'Enable', 'on');
            set(HighButton, 'Enable', 'on');
            set(Low_sld, 'Enable', 'on');
            set(High_sld, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
        function HighContrast(src,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            temp = get(High_sld,'Value');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(LowButton, 'Enable', 'off');
            set(HighButton, 'Enable', 'off');
            set(Low_sld, 'Enable', 'off');
            set(High_sld, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if MergeChannel
                if Z_Projection&&~T_Projection
                    if temp~=Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)
                        Z_Projection_ContrastAdjusted=1;
                        Merge_ContrastAdjusted=1;
                    end
                elseif ~Z_Projection&&T_Projection
                    if temp~=Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)
                        T_Projection_ContrastAdjusted=1;
                        Merge_ContrastAdjusted=1;
                    end
                elseif Z_Projection&&T_Projection
                    error('Not Currently Possible')
                else
                    if temp~=Channel_Info(Channel).Normalized_Display_Limits(2)
                        Merge_ContrastAdjusted=1;
                    end
                end
            else
                if Z_Projection&&~T_Projection
                    if temp~=Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)
                        Z_Projection_ContrastAdjusted=1;
                        Merge_ContrastAdjusted=1;
                    end
                elseif ~Z_Projection&&T_Projection
                    if temp~=Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)
                        T_Projection_ContrastAdjusted=1;
                        Merge_ContrastAdjusted=1;
                    end
                elseif Z_Projection&&T_Projection
                    error('Not Currently Possible')
                else
                    if temp~=Channel_Info(Channel).Normalized_Display_Limits(2)
                        Merge_ContrastAdjusted=1;
                    end
                end
            end
            if MergeChannel
                if Z_Projection&&~T_Projection
                    if temp<=Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1)
                        warning('Not possible')
                        set(src,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                    else
                        Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)=temp;
                        Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)=Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).Z_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).Z_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Z_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        Merge_Z_Projection
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)))
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                    Merge_Z_Projection
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                elseif ~Z_Projection&&T_Projection
                    if temp<=Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1)
                        warning('Not possible')
                        set(src,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                    else
                        Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)=temp;
                        Channel_Info(Channel).T_Projection_Data.Display_Limits(2)=Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).T_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).T_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).T_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).T_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).T_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(HighDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(2)))
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                    Merge_T_Projection
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                elseif Z_Projection&&T_Projection
                    error('Not Currently Possible')
                else
                    if temp<=Channel_Info(Channel).Normalized_Display_Limits(1)
                        warning('Not possible')
                        set(src,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                    else
                        Channel_Info(Channel).Normalized_Display_Limits(2)=temp;
                        Channel_Info(Channel).Display_Limits(2)=Channel_Info(Channel).Normalized_Display_Limits(2)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).ColorMap,...
                            Channel_Info(Channel).ValueAdjust,...
                            Channel_Info(Channel).ContrastHigh,...
                            Channel_Info(Channel).ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Display_Limits(2)))
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                        warning on
                        Merge_Channels
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                   end
                end
            else
                if Z_Projection&&~T_Projection
                    if temp<=Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1)
                        warning('Not possible')
                        set(src,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                    else
                        Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)=temp;
                        Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)=Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).Z_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).Z_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Z_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)))
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                elseif ~Z_Projection&&T_Projection
                    if temp<=Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1)
                        warning('Not possible')
                        set(src,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                    else
                        Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)=temp;
                        Channel_Info(Channel).T_Projection_Data.Display_Limits(2)=Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).T_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).T_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).T_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).T_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).T_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(HighDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(2)))
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                elseif Z_Projection&&T_Projection
                    error('Not Currently Possible')
                else
                    if temp<=Channel_Info(Channel).Normalized_Display_Limits(1)
                        warning('Not possible')
                        set(src,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                    else
                        Channel_Info(Channel).Normalized_Display_Limits(2)=temp;
                        Channel_Info(Channel).Display_Limits(2)=Channel_Info(Channel).Normalized_Display_Limits(2)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).ColorMap,...
                            Channel_Info(Channel).ValueAdjust,...
                            Channel_Info(Channel).ContrastHigh,...
                            Channel_Info(Channel).ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Display_Limits(2)))
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                        warning on
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                end
            end
            clear temp
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(LowButton, 'Enable', 'on');
            set(HighButton, 'Enable', 'on');
            set(Low_sld, 'Enable', 'on');
            set(High_sld, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
        function SetHighContrast(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            temp = str2num(get(HighDisp,'String'));
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(LowButton, 'Enable', 'off');
            set(HighButton, 'Enable', 'off');
            set(Low_sld, 'Enable', 'off');
            set(High_sld, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if MergeChannel
                Merge_ContrastAdjusted=1;
                if Z_Projection&&~T_Projection
                    Z_Projection_ContrastAdjusted=1;
                    if temp<=Channel_Info(Channel).Z_Projection_Data.Display_Limits(1)
                        warning('Not possible')
                    else
                        Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)=temp;
                        Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits=...
                            (Channel_Info(Channel).Z_Projection_Data.Display_Limits-...
                            Channel_Info(Channel).DisplayMinVal)/Channel_Info(Channel).DisplayValDiff;
                        [   Channel_Info(Channel).Z_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).Z_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Z_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)))
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                    Merge_Z_Projection
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                elseif ~Z_Projection&&T_Projection
                    T_Projection_ContrastAdjusted=1;
                    if temp<=Channel_Info(Channel).T_Projection_Data.Display_Limits(1)
                        warning('Not possible')
                    else
                        Channel_Info(Channel).T_Projection_Data.Display_Limits(2)=temp;
                        Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits=...
                            (Channel_Info(Channel).T_Projection_Data.Display_Limits-...
                            Channel_Info(Channel).DisplayMinVal)/Channel_Info(Channel).DisplayValDiff;
                        [   Channel_Info(Channel).T_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).T_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).T_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).T_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).T_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(HighDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(2)))
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                    Merge_T_Projection
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                elseif Z_Projection&&T_Projection
                    error('Not Currently Possible')
                else
                    if temp<=Channel_Info(Channel).Display_Limits(1)
                        warning('Not possible')
                    else
                        Channel_Info(Channel).Display_Limits(2)=temp;
                        Channel_Info(Channel).Normalized_Display_Limits=...
                            (Channel_Info(Channel).Display_Limits-...
                            Channel_Info(Channel).DisplayMinVal)/Channel_Info(Channel).DisplayValDiff;
                        [   Channel_Info(Channel).ColorMap,...
                            Channel_Info(Channel).ValueAdjust,...
                            Channel_Info(Channel).ContrastHigh,...
                            Channel_Info(Channel).ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Display_Limits(2)))
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                        warning on
                        Merge_Channels
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                end
            else
                if Z_Projection&&~T_Projection
                    Z_Projection_ContrastAdjusted=1;
                    if temp<=Channel_Info(Channel).Z_Projection_Data.Display_Limits(1)
                        warning('Not possible')
                    else
                        Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)=temp;
                        Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits=...
                            (Channel_Info(Channel).Z_Projection_Data.Display_Limits-...
                            Channel_Info(Channel).DisplayMinVal)/Channel_Info(Channel).DisplayValDiff;
                        [   Channel_Info(Channel).Z_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).Z_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Z_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)))
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                elseif ~Z_Projection&&T_Projection
                    T_Projection_ContrastAdjusted=1;
                    if temp<=Channel_Info(Channel).T_Projection_Data.Display_Limits(1)
                        warning('Not possible')
                    else
                        Channel_Info(Channel).T_Projection_Data.Display_Limits(2)=temp;
                        Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits=...
                            (Channel_Info(Channel).T_Projection_Data.Display_Limits-...
                            Channel_Info(Channel).DisplayMinVal)/Channel_Info(Channel).DisplayValDiff;
                        [   Channel_Info(Channel).T_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).T_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).T_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).T_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).T_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(HighDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(2)))
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                elseif Z_Projection&&T_Projection
                    error('Not Currently Possible')
                else
                    if temp<=Channel_Info(Channel).Display_Limits(1)
                        warning('Not possible')
                    else
                        Channel_Info(Channel).Display_Limits(2)=temp;
                        Channel_Info(Channel).Normalized_Display_Limits=...
                            (Channel_Info(Channel).Display_Limits-...
                            Channel_Info(Channel).DisplayMinVal)/Channel_Info(Channel).DisplayValDiff;
                        [   Channel_Info(Channel).ColorMap,...
                            Channel_Info(Channel).ValueAdjust,...
                            Channel_Info(Channel).ContrastHigh,...
                            Channel_Info(Channel).ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Display_Limits(2)))
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                        warning on
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                end
            end
            clear temp
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(LowButton, 'Enable', 'on');
            set(HighButton, 'Enable', 'on');
            set(Low_sld, 'Enable', 'on');
            set(High_sld, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
        function LowContrast(src,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            temp = get(Low_sld,'Value');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(LowButton, 'Enable', 'off');
            set(HighButton, 'Enable', 'off');
            set(Low_sld, 'Enable', 'off');
            set(High_sld, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if MergeChannel
                if Z_Projection&&~T_Projection
                    if temp~=Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1)
                        Z_Projection_ContrastAdjusted=1;
                        Merge_ContrastAdjusted=1;
                    end
                elseif ~Z_Projection&&T_Projection
                    if temp~=Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1)
                        T_Projection_ContrastAdjusted=1;
                        Merge_ContrastAdjusted=1;
                    end
                elseif Z_Projection&&T_Projection
                    error('Not Currently Possible')
                else
                    if temp~=Channel_Info(Channel).Normalized_Display_Limits(1)
                        Merge_ContrastAdjusted=1;
                    end
                end
            else
                if Z_Projection&&~T_Projection
                    if temp~=Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1)
                        Z_Projection_ContrastAdjusted=1;
                        Merge_ContrastAdjusted=1;
                    end
                elseif ~Z_Projection&&T_Projection
                    if temp~=Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1)
                        T_Projection_ContrastAdjusted=1;
                        Merge_ContrastAdjusted=1;
                    end
                elseif Z_Projection&&T_Projection
                    error('Not Currently Possible')
                else
                    if temp~=Channel_Info(Channel).Normalized_Display_Limits(1)
                        Merge_ContrastAdjusted=1;
                    end
                end
            end
            if MergeChannel
                if Z_Projection&&~T_Projection
                    if Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)<=temp
                        warning('Not possible')
                        set(src,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1))
                    else
                        Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1)=temp;
                        Channel_Info(Channel).Z_Projection_Data.Display_Limits(1)=Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).Z_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).Z_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Z_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(LowDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(1)))
                        warning off
                        set(Low_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1))
                        warning on
                    Merge_Z_Projection
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                elseif ~Z_Projection&&T_Projection
                    if Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)<=temp
                        warning('Not possible')
                        set(src,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1))
                    else
                        Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1)=temp;
                        Channel_Info(Channel).T_Projection_Data.Display_Limits(1)=Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).T_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).T_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).T_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).T_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).T_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(LowDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(1)))
                        warning off
                        set(Low_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1))
                        warning on
                    Merge_T_Projection
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                elseif Z_Projection&&T_Projection
                    error('Not Currently Possible')
                else
                    if Channel_Info(Channel).Normalized_Display_Limits(2)<=temp
                        warning('Not possible')
                        set(src,'Value',Channel_Info(Channel).Normalized_Display_Limits(1))
                    else
                        Channel_Info(Channel).Normalized_Display_Limits(1)=temp;
                        Channel_Info(Channel).Display_Limits(1)=Channel_Info(Channel).Normalized_Display_Limits(1)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).ColorMap,...
                            Channel_Info(Channel).ValueAdjust,...
                            Channel_Info(Channel).ContrastHigh,...
                            Channel_Info(Channel).ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(LowDisp,'String',num2str(Channel_Info(Channel).Display_Limits(1)))
                        warning off
                        set(Low_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(1))
                        warning on
                        Merge_Channels
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                end
            else
                if Z_Projection&&~T_Projection
                    if Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)<=temp
                        warning('Not possible')
                        set(src,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1))
                    else
                        Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1)=temp;
                        Channel_Info(Channel).Z_Projection_Data.Display_Limits(1)=Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).Z_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).Z_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Z_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(LowDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(1)))
                        warning off
                        set(Low_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1))
                        warning on
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                elseif ~Z_Projection&&T_Projection
                    if Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)<=temp
                        warning('Not possible')
                        set(src,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1))
                    else
                        Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1)=temp;
                        Channel_Info(Channel).T_Projection_Data.Display_Limits(1)=Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).T_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).T_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).T_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).T_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).T_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(LowDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(1)))
                        warning off
                        set(Low_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1))
                        warning on
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                elseif Z_Projection&&T_Projection
                    error('Not Currently Possible')
                else
                    if Channel_Info(Channel).Normalized_Display_Limits(2)<=temp
                        warning('Not possible')
                        set(src,'Value',Channel_Info(Channel).Normalized_Display_Limits(1))
                    else
                        Channel_Info(Channel).Normalized_Display_Limits(1)=temp;
                        Channel_Info(Channel).Display_Limits(1)=Channel_Info(Channel).Normalized_Display_Limits(1)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).ColorMap,...
                            Channel_Info(Channel).ValueAdjust,...
                            Channel_Info(Channel).ContrastHigh,...
                            Channel_Info(Channel).ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(LowDisp,'String',num2str(Channel_Info(Channel).Display_Limits(1)))
                        warning off
                        set(Low_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(1))
                        warning on
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                end
            end
            clear temp
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(LowButton, 'Enable', 'on');
            set(HighButton, 'Enable', 'on');
            set(Low_sld, 'Enable', 'on');
            set(High_sld, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
        function SetLowContrast(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            temp = str2num(get(LowDisp,'String'));
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(LowButton, 'Enable', 'off');
            set(HighButton, 'Enable', 'off');
            set(Low_sld, 'Enable', 'off');
            set(High_sld, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if MergeChannel
                Merge_ContrastAdjusted=1;
                if Z_Projection&&~T_Projection
                    if Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)<=temp
                        warning('Not possible')
                    else
                        Channel_Info(Channel).Z_Projection_Data.Display_Limits(1)=temp;
                        Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits=...
                            (Channel_Info(Channel).Z_Projection_Data.Display_Limits-...
                            Channel_Info(Channel).DisplayMinVal)/Channel_Info(Channel).DisplayValDiff;
                        [   Channel_Info(Channel).Z_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).Z_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Z_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(LowDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(1)))
                        warning off
                        set(Low_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1))
                        warning on
                    Z_Projection_ContrastAdjusted=1;
                    Merge_Z_Projection
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                elseif ~Z_Projection&&T_Projection
                    if Channel_Info(Channel).T_Projection_Data.Display_Limits(2)<=temp
                        warning('Not possible')
                    else
                        Channel_Info(Channel).T_Projection_Data.Display_Limits(1)=temp;
                        Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits=...
                            (Channel_Info(Channel).T_Projection_Data.Display_Limits-...
                            Channel_Info(Channel).DisplayMinVal)/Channel_Info(Channel).DisplayValDiff;
                        [   Channel_Info(Channel).T_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).T_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).T_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).T_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).T_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(LowDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(1)))
                        warning off
                        set(Low_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1))
                        warning on
                    T_Projection_ContrastAdjusted=1;
                    Merge_T_Projection
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                elseif Z_Projection&&T_Projection
                    error('Not Currently Possible')
                else
                    if Channel_Info(Channel).Display_Limits(2)<=temp
                        warning('Not possible')
                    else
                        Channel_Info(Channel).Display_Limits(1)=temp;
                        Channel_Info(Channel).Normalized_Display_Limits=...
                            (Channel_Info(Channel).Display_Limits-...
                            Channel_Info(Channel).DisplayMinVal)/Channel_Info(Channel).DisplayValDiff;
                        [   Channel_Info(Channel).ColorMap,...
                            Channel_Info(Channel).ValueAdjust,...
                            Channel_Info(Channel).ContrastHigh,...
                            Channel_Info(Channel).ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(LowDisp,'String',num2str(Channel_Info(Channel).Display_Limits(1)))
                        warning off
                        set(Low_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(1))
                        warning on
                        Merge_Channels
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                end
            else
                if Z_Projection&&~T_Projection
                    Z_Projection_ContrastAdjusted=1;
                    if Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)<=temp
                        warning('Not possible')
                    else
                        Channel_Info(Channel).Z_Projection_Data.Display_Limits(1)=temp;
                        Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits=...
                            (Channel_Info(Channel).Z_Projection_Data.Display_Limits-...
                            Channel_Info(Channel).DisplayMinVal)/Channel_Info(Channel).DisplayValDiff;
                        [   Channel_Info(Channel).Z_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).Z_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Z_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(LowDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(1)))
                        warning off
                        set(Low_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1))
                        warning on
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                elseif ~Z_Projection&&T_Projection
                    T_Projection_ContrastAdjusted=1;
                    if Channel_Info(Channel).T_Projection_Data.Display_Limits(2)<=temp
                        warning('Not possible')
                    else
                        Channel_Info(Channel).T_Projection_Data.Display_Limits(1)=temp;
                        Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits=...
                            (Channel_Info(Channel).T_Projection_Data.Display_Limits-...
                            Channel_Info(Channel).DisplayMinVal)/Channel_Info(Channel).DisplayValDiff;
                        [   Channel_Info(Channel).T_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).T_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).T_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).T_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).T_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(LowDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(1)))
                        warning off
                        set(Low_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1))
                        warning on
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                elseif Z_Projection&&T_Projection
                    error('Not Currently Possible')
                else
                    if Channel_Info(Channel).Display_Limits(2)<=temp
                        warning('Not possible')
                    else
                        Channel_Info(Channel).Display_Limits(1)=temp;
                        Channel_Info(Channel).Normalized_Display_Limits=...
                            (Channel_Info(Channel).Display_Limits-...
                            Channel_Info(Channel).DisplayMinVal)/Channel_Info(Channel).DisplayValDiff;
                        [   Channel_Info(Channel).ColorMap,...
                            Channel_Info(Channel).ValueAdjust,...
                            Channel_Info(Channel).ContrastHigh,...
                            Channel_Info(Channel).ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Display_Limits,Channel_Info(Channel).ColorScalar);
                        set(LowDisp,'String',num2str(Channel_Info(Channel).Display_Limits(1)))
                        warning off
                        set(Low_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(1))
                        warning on
                        if RGB_Stack
                        else
                            ContrastUpdate
                        end
                    end
                end
            end
            clear temp
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(LowButton, 'Enable', 'on');
            set(HighButton, 'Enable', 'on');
            set(Low_sld, 'Enable', 'on');
            set(High_sld, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function AutoContrast(~,~,~)
            AutoContrastOn=get(AutoContButton,'value');
            set(AutoContButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if AutoContrastOn
                error('Not Ready yet!')
                
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(AutoContButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function LinkContrast(~,~,~)
            set(LinkContButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if MergeChannel
                Merge_ContrastAdjusted=1;
                if Z_Projection&&~T_Projection
                    TempDisplayLimits=Channel_Info(Channel).Z_Projection_Data.Display_Limits;
                    for cccc=1:length(Channel_Info)
                        Channel_Info(cccc).Z_Projection_Data.Display_Limits=TempDisplayLimits;
                        Channel_Info(cccc).Z_Projection_Data.Normalized_Display_Limits=...
                            (Channel_Info(cccc).Z_Projection_Data.Display_Limits-...
                            Channel_Info(cccc).DisplayMinVal)/Channel_Info(cccc).DisplayValDiff;
                        [   Channel_Info(cccc).Z_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(cccc).Z_Projection_Data.ValueAdjust,...
                            Channel_Info(cccc).Z_Projection_Data.ContrastHigh,...
                            Channel_Info(cccc).Z_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(cccc).DisplayColorMap,Channel_Info(cccc).DisplayColorMapCode,...
                                Channel_Info(cccc).Z_Projection_Data.Display_Limits,Channel_Info(cccc).ColorScalar);
                    end
                    Z_Projection_ContrastAdjusted=1;
                    Merge_Z_Projection
                elseif ~Z_Projection&&T_Projection
                    TempDisplayLimits=Channel_Info(Channel).T_Projection_Data.Display_Limits;
                    for cccc=1:length(Channel_Info)
                        Channel_Info(cccc).T_Projection_Data.Display_Limits=TempDisplayLimits;
                        Channel_Info(cccc).T_Projection_Data.Normalized_Display_Limits=...
                            (Channel_Info(cccc).T_Projection_Data.Display_Limits-...
                            Channel_Info(cccc).DisplayMinVal)/Channel_Info(cccc).DisplayValDiff;
                        [   Channel_Info(cccc).T_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(cccc).T_Projection_Data.ValueAdjust,...
                            Channel_Info(cccc).T_Projection_Data.ContrastHigh,...
                            Channel_Info(cccc).T_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(cccc).DisplayColorMap,Channel_Info(cccc).DisplayColorMapCode,...
                                Channel_Info(cccc).T_Projection_Data.Display_Limits,Channel_Info(cccc).ColorScalar);
                    end
                    T_Projection_ContrastAdjusted=1;
                    Merge_T_Projection
                elseif Z_Projection&&T_Projection
                    error('Not Currently Possible')
                else
                    TempDisplayLimits=Channel_Info(Channel).Display_Limits;
                    for cccc=1:length(Channel_Info)
                        Channel_Info(cccc).Display_Limits=TempDisplayLimits;
                        Channel_Info(cccc).Normalized_Display_Limits=...
                            (Channel_Info(cccc).Display_Limits-...
                            Channel_Info(cccc).DisplayMinVal)/Channel_Info(cccc).DisplayValDiff;
                        [   Channel_Info(cccc).ColorMap,...
                            Channel_Info(cccc).ValueAdjust,...
                            Channel_Info(cccc).ContrastHigh,...
                            Channel_Info(cccc).ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(cccc).DisplayColorMap,Channel_Info(cccc).DisplayColorMapCode,...
                                Channel_Info(cccc).Display_Limits,Channel_Info(cccc).ColorScalar);
                    end
                    Merge_Channels
                end
            else
                if Z_Projection&&~T_Projection
                    Z_Projection_ContrastAdjusted=1;
                    TempDisplayLimits=Channel_Info(Channel).Z_Projection_Data.Display_Limits;
                    for cccc=1:length(Channel_Info)
                        Channel_Info(cccc).Z_Projection_Data.Display_Limits=TempDisplayLimits;
                        Channel_Info(cccc).Z_Projection_Data.Normalized_Display_Limits=...
                            (Channel_Info(cccc).Z_Projection_Data.Display_Limits-...
                            Channel_Info(cccc).DisplayMinVal)/Channel_Info(cccc).DisplayValDiff;
                        [   Channel_Info(cccc).Z_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(cccc).Z_Projection_Data.ValueAdjust,...
                            Channel_Info(cccc).Z_Projection_Data.ContrastHigh,...
                            Channel_Info(cccc).Z_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(cccc).DisplayColorMap,Channel_Info(cccc).DisplayColorMapCode,...
                                Channel_Info(cccc).Z_Projection_Data.Display_Limits,Channel_Info(cccc).ColorScalar);
                    end
                elseif ~Z_Projection&&T_Projection
                    T_Projection_ContrastAdjusted=1;
                    TempDisplayLimits=Channel_Info(Channel).T_Projection_Data.Display_Limits;
                    for cccc=1:length(Channel_Info)
                        Channel_Info(cccc).T_Projection_Data.Display_Limits=TempDisplayLimits;
                        Channel_Info(cccc).T_Projection_Data.Normalized_Display_Limits=...
                            (Channel_Info(cccc).T_Projection_Data.Display_Limits-...
                            Channel_Info(cccc).DisplayMinVal)/Channel_Info(cccc).DisplayValDiff;
                        [   Channel_Info(cccc).T_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(cccc).T_Projection_Data.ValueAdjust,...
                            Channel_Info(cccc).T_Projection_Data.ContrastHigh,...
                            Channel_Info(cccc).T_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(cccc).DisplayColorMap,Channel_Info(cccc).DisplayColorMapCode,...
                                Channel_Info(cccc).T_Projection_Data.Display_Limits,Channel_Info(cccc).ColorScalar);
                    end
                elseif Z_Projection&&T_Projection
                    error('Not Currently Possible')
                else
                    TempDisplayLimits=Channel_Info(Channel).Display_Limits;
                    for cccc=1:length(Channel_Info)
                        Channel_Info(cccc).Display_Limits=TempDisplayLimits;
                        Channel_Info(cccc).Normalized_Display_Limits=...
                            (Channel_Info(cccc).Display_Limits-...
                            Channel_Info(cccc).DisplayMinVal)/Channel_Info(cccc).DisplayValDiff;
                        [   Channel_Info(cccc).ColorMap,...
                            Channel_Info(cccc).ValueAdjust,...
                            Channel_Info(cccc).ContrastHigh,...
                            Channel_Info(cccc).ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(cccc).DisplayColorMap,Channel_Info(cccc).DisplayColorMapCode,...
                                Channel_Info(cccc).Display_Limits,Channel_Info(cccc).ColorScalar);
                    end
                end
            end
            if RGB_Stack
            else
                ContrastUpdate
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(LinkContButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function ReduceContrast
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(LowButton, 'Enable', 'off');
            set(HighButton, 'Enable', 'off');
            set(Low_sld, 'Enable', 'off');
            set(High_sld, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            Merge_ContrastAdjusted=1;
            if MergeChannel
                if Z_Projection&&~T_Projection
                    temp = Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)+Channel_Info(Channel).Normalized_StepUnits(2);
                    if temp>1
                        warning('Reducing Contrast Not possible')
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)))
                    else
                        Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)=temp;clear temp
                        Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)=Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).Z_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).Z_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Z_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)))
                    Z_Projection_ContrastAdjusted=1;
                    Merge_Z_Projection
                    if RGB_Stack
                    else
                        ContrastUpdate
                    end
                    end
                elseif ~Z_Projection&&T_Projection
                    temp = Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)+Channel_Info(Channel).Normalized_StepUnits(2);
                    if temp>1
                        warning('Reducing Contrast Not possible')
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(2)))
                    else
                        Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)=temp;clear temp
                        Channel_Info(Channel).T_Projection_Data.Display_Limits(2)=Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).T_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).T_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).T_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).T_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).T_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(2)))
                    T_Projection_ContrastAdjusted=1;
                    Merge_T_Projection
                    if RGB_Stack
                    else
                        ContrastUpdate
                    end
                    end
                elseif Z_Projection&&T_Projection
                    error('Not Currently Possible')
                else
                    temp = Channel_Info(Channel).Normalized_Display_Limits(2)+Channel_Info(Channel).Normalized_StepUnits(2);
                    if temp>1
                        warning('Reducing Contrast Not possible')
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Display_Limits(2)))
                    else
                        Channel_Info(Channel).Normalized_Display_Limits(2)=temp;clear temp
                        Channel_Info(Channel).Display_Limits(2)=Channel_Info(Channel).Normalized_Display_Limits(2)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).ColorMap,...
                            Channel_Info(Channel).ValueAdjust,...
                            Channel_Info(Channel).ContrastHigh,...
                            Channel_Info(Channel).ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Display_Limits,Channel_Info(Channel).ColorScalar);
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Display_Limits(2)))
                    Merge_Channels
                    if RGB_Stack
                    else
                        ContrastUpdate
                    end
                    end
                end
            else
                if Z_Projection&&~T_Projection
                    temp = Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)+Channel_Info(Channel).Normalized_StepUnits(2);
                    if temp>1
                        warning('Reducing Contrast Not possible')
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)))
                    else
                        Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)=temp;clear temp
                        Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)=Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).Z_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).Z_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Z_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)))
                    if RGB_Stack
                    else
                        ContrastUpdate
                    end
                    end
                elseif ~Z_Projection&&T_Projection
                    temp = Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)+Channel_Info(Channel).Normalized_StepUnits(2);
                    if temp>1
                        warning('Reducing Contrast Not possible')
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(2)))
                    else
                        Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)=temp;clear temp
                        Channel_Info(Channel).T_Projection_Data.Display_Limits(2)=Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).T_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).T_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).T_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).T_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).T_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(2)))
                    if RGB_Stack
                    else
                        ContrastUpdate
                    end
                    end
                elseif Z_Projection&&T_Projection
                    error('Not Currently Possible')
                else
                    temp = Channel_Info(Channel).Normalized_Display_Limits(2)+Channel_Info(Channel).Normalized_StepUnits(2);
                    if temp>1
                        warning('Reducing Contrast Not possible')
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Display_Limits(2)))
                    else
                        Channel_Info(Channel).Normalized_Display_Limits(2)=temp;clear temp
                        Channel_Info(Channel).Display_Limits(2)=Channel_Info(Channel).Normalized_Display_Limits(2)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).ColorMap,...
                            Channel_Info(Channel).ValueAdjust,...
                            Channel_Info(Channel).ContrastHigh,...
                            Channel_Info(Channel).ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Display_Limits,Channel_Info(Channel).ColorScalar);
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Display_Limits(2)))
                    if RGB_Stack
                    else
                        ContrastUpdate
                    end
                    end
                end
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(LowButton, 'Enable', 'on');
            set(HighButton, 'Enable', 'on');
            set(Low_sld, 'Enable', 'on');
            set(High_sld, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
%             ColorBarDisplay(ViewerFig,ColorBarAxis,ColorBarAxisPosition)
%             CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
%             [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %         if ~RGB_Stack
    %             HistDisplay(HistAxis,HistAxisPosition)
    %             if T_Stack
    %                 TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
    %             end
    %         end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        function EnhanceContrast
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(LowButton, 'Enable', 'off');
            set(HighButton, 'Enable', 'off');
            set(Low_sld, 'Enable', 'off');
            set(High_sld, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            Merge_ContrastAdjusted=1;
            if MergeChannel
                if Z_Projection&&~T_Projection
                    temp = Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)-Channel_Info(Channel).Normalized_StepUnits(2);
                    if temp<=Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1)
                        warning('Enhancing Contrast Not possible')
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)))
                    else
                        Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)=temp;clear temp
                        Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)=...
                            Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).Z_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).Z_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Z_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)))
                    Z_Projection_ContrastAdjusted=1;
                    Merge_Z_Projection
                    if RGB_Stack
                    else
                        ContrastUpdate
                    end
                    end
                elseif ~Z_Projection&&T_Projection
                    temp = Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)-Channel_Info(Channel).Normalized_StepUnits(2);
                    if temp<=Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1)
                        warning('Enhancing Contrast Not possible')
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(2)))
                    else
                        Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)=temp;clear temp
                        Channel_Info(Channel).T_Projection_Data.Display_Limits(2)=...
                            Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).T_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).T_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).T_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).T_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).T_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(2)))
                    T_Projection_ContrastAdjusted=1;
                    Merge_T_Projection
                    if RGB_Stack
                    else
                        ContrastUpdate
                    end
                    end
                elseif Z_Projection&&T_Projection
                    error('Not Currently Possible')
                else
                    temp = Channel_Info(Channel).Normalized_Display_Limits(2)-Channel_Info(Channel).Normalized_StepUnits(2);
                    if temp<=Channel_Info(Channel).Normalized_Display_Limits(1)
                        warning('Enhancing Contrast Not possible')
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Display_Limits(2)))
                    else
                        Channel_Info(Channel).Normalized_Display_Limits(2)=temp;clear temp
                        Channel_Info(Channel).Display_Limits(2)=Channel_Info(Channel).Normalized_Display_Limits(2)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).ColorMap,...
                            Channel_Info(Channel).ValueAdjust,...
                            Channel_Info(Channel).ContrastHigh,...
                            Channel_Info(Channel).ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Display_Limits,Channel_Info(Channel).ColorScalar);
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Display_Limits(2)))
                    Merge_Channels
                    if RGB_Stack
                    else
                        ContrastUpdate
                    end
                    end
                end
            else
                if Z_Projection&&~T_Projection
                    temp = Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)-Channel_Info(Channel).Normalized_StepUnits(2);
                    if temp<=Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1)
                        warning('Enhancing Contrast Not possible')
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)))
                    else
                        Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)=temp;clear temp
                        Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)=...
                            Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).Z_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).Z_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).Z_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Z_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)))
                    if RGB_Stack
                    else
                        ContrastUpdate
                    end
                    end
                elseif ~Z_Projection&&T_Projection
                    temp = Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)-Channel_Info(Channel).Normalized_StepUnits(2);
                    if temp<=Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1)
                        warning('Enhancing Contrast Not possible')
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(2)))
                    else
                        Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)=temp;clear temp
                        Channel_Info(Channel).T_Projection_Data.Display_Limits(2)=...
                            Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).T_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(Channel).T_Projection_Data.ValueAdjust,...
                            Channel_Info(Channel).T_Projection_Data.ContrastHigh,...
                            Channel_Info(Channel).T_Projection_Data.ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).T_Projection_Data.Display_Limits,Channel_Info(Channel).ColorScalar);
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(2)))
                    if RGB_Stack
                    else
                        ContrastUpdate
                    end
                    end
                elseif Z_Projection&&T_Projection
                    error('Not Currently Possible')
                else
                    temp = Channel_Info(Channel).Normalized_Display_Limits(2)-Channel_Info(Channel).Normalized_StepUnits(2);
                    if temp<=Channel_Info(Channel).Normalized_Display_Limits(1)
                        warning('Enhancing Contrast Not possible')
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Display_Limits(2)))
                    else
                        Channel_Info(Channel).Normalized_Display_Limits(2)=temp;clear temp
                        Channel_Info(Channel).Display_Limits(2)=Channel_Info(Channel).Normalized_Display_Limits(2)*Channel_Info(Channel).DisplayValDiff+Channel_Info(Channel).DisplayMinVal;
                        [   Channel_Info(Channel).ColorMap,...
                            Channel_Info(Channel).ValueAdjust,...
                            Channel_Info(Channel).ContrastHigh,...
                            Channel_Info(Channel).ContrastLow]=...
                            StackViewer_UniversalColorMap(Channel_Info(Channel).DisplayColorMap,Channel_Info(Channel).DisplayColorMapCode,...
                                Channel_Info(Channel).Display_Limits,Channel_Info(Channel).ColorScalar);
                        warning off
                        set(High_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                        warning on
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Display_Limits(2)))
                    if RGB_Stack
                    else
                        ContrastUpdate
                    end
                    end
                end
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(LowButton, 'Enable', 'on');
            set(HighButton, 'Enable', 'on');
            set(Low_sld, 'Enable', 'on');
            set(High_sld, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
%             ColorBarDisplay(ViewerFig,ColorBarAxis,ColorBarAxisPosition)
%             CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
%             [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %         if ~RGB_Stack
    %             HistDisplay(HistAxis,HistAxisPosition)
    %             if T_Stack
    %                 TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
    %             end
    %         end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end  
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function ContrastUpdate
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            ColorBarDisplay(ViewerFig,ColorBarAxis,ColorBarAxisPosition)
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %         if ~RGB_Stack
    %             HistDisplay(HistAxis,HistAxisPosition)
    %             if T_Stack
    %                 TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
    %             end
    %         end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function ColorBarDisplay(ViewerFig,ColorBarAxis,ColorBarAxisPosition)
            figure(ViewerFig)
            axes(ColorBarAxis)
            cla(ColorBarAxis,'reset')
            %ColorBarAxis=axes('Position',ColorBarAxisPosition);
            if Z_Projection&&~T_Projection
                imagesc(Channel_Info(Channel).Z_Projection_Data.Display_Limits);
            elseif ~Z_Projection&&T_Projection
                imagesc(Channel_Info(Channel).T_Projection_Data.Display_Limits);
            elseif Z_Projection&&T_Projection
                error('Not Currently Possible')
            else
                imagesc(Channel_Info(Channel).Display_Limits);
            end
            hold on
            if Z_Projection&&~T_Projection
                colormap(ColorBarAxis,Channel_Info(Channel).Z_Projection_Data.ColorMaps.ColorMap);
            elseif ~Z_Projection&&T_Projection
                colormap(ColorBarAxis,Channel_Info(Channel).T_Projection_Data.ColorMaps.ColorMap);
            else
                colormap(ColorBarAxis,Channel_Info(Channel).ColorMap);
            end
            xlim([10,11])
            ylim([10,11])
            box off
            axis off
            ColorBar=colorbar('Position',ColorBarPosition,'color','k','axislocation','in');
            set(ColorBarAxis,'units','normalized','Position',ColorBarAxisPosition)
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function FrameAdvance
            BufferViewerImageAxes=horzcat(BufferViewerImageAxes,{ViewerImageAxis});
            BufferMaskAxes=horzcat(BufferMaskAxes,MaskAxes);
            BufferTileAxes=horzcat(BufferTileAxes,TileAxes);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if Frame==Last_T
                Frame=1;
            else
                Frame=Frame+1;
            end
            set(Frame_sld,'Value',Frame)
            set(FramePos,'String',num2str(Frame))
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(Frame_sld, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(Frame_sld, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        function FrameRetreat
            BufferViewerImageAxes=horzcat(BufferViewerImageAxes,{ViewerImageAxis});
            BufferMaskAxes=horzcat(BufferMaskAxes,MaskAxes);
            BufferTileAxes=horzcat(BufferTileAxes,TileAxes);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if Frame==1
                Frame=Last_T;
            else
                Frame=Frame-1;
            end
            set(Frame_sld,'Value',Frame)
            set(FramePos,'String',num2str(Frame))
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(Frame_sld, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(Frame_sld, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function SliceUp
            BufferViewerImageAxes=horzcat(BufferViewerImageAxes,{ViewerImageAxis});
            BufferMaskAxes=horzcat(BufferMaskAxes,MaskAxes);
            BufferTileAxes=horzcat(BufferTileAxes,TileAxes);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if Slice<Last_Z
                Slice=Slice+1;
            elseif Slice==Last_Z
                Slice=1;
            else
            end
            set(Slice_sld,'Value',Slice)
            set(SlicePos,'String',num2str(Slice))
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(Slice_sld, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if ~RGB_Stack
                if T_Stack
                    TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                end
                if LiveHist
                    HistDisplay(HistAxis,HistAxisPosition);
                end
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(Slice_sld, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        function SliceDown
            BufferViewerImageAxes=horzcat(BufferViewerImageAxes,{ViewerImageAxis});
            BufferMaskAxes=horzcat(BufferMaskAxes,MaskAxes);
            BufferTileAxes=horzcat(BufferTileAxes,TileAxes);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if Slice>1
                Slice=Slice-1;
            elseif Slice==1
                Slice=Last_Z;
            else
            end
            set(Slice_sld,'Value',Slice)
            set(SlicePos,'String',num2str(Slice))
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(Slice_sld, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if ~RGB_Stack
                if T_Stack
                    TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                end
                if LiveHist
                    HistDisplay(HistAxis,HistAxisPosition);
                end
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(Slice_sld, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end  
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function ChannelUp
            BufferViewerImageAxes=horzcat(BufferViewerImageAxes,{ViewerImageAxis});
            BufferMaskAxes=horzcat(BufferMaskAxes,MaskAxes);
            BufferTileAxes=horzcat(BufferTileAxes,TileAxes);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if Channel<Last_C
                Channel=Channel+1;
            elseif Channel==Last_C
                Channel=1;
            else
            end
            set(Channel_sld,'Value',Channel)
            set(ChannelPos,'String',num2str(Channel))
            set(ChannelLabelText,'String',Channel_Labels{Channel});
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(Channel_sld, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            set(ColorMapList,'Value',Channel_Info(Channel).DisplayColorMapIndex);
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            ColorBarDisplay(ViewerFig,ColorBarAxis,ColorBarAxisPosition);
            if Z_Projection&&~T_Projection
                set(LowDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(1)))
                set(HighDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)))
                warning off
                set(Low_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1))
                set(High_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                warning on
            elseif ~Z_Projection&&T_Projection
                set(LowDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(1)))
                set(HighDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(2)))
                warning off
                set(Low_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1))
                set(High_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                warning on
            elseif Z_Projection&&T_Projection
                error('Not Currently Possible')
            else
                set(LowDisp,'String',num2str(Channel_Info(Channel).Display_Limits(1)))
                set(HighDisp,'String',num2str(Channel_Info(Channel).Display_Limits(2)))
                warning off
                set(Low_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(1))
                set(High_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                warning on
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if ~RGB_Stack
                if T_Stack
                    TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                end
                if LiveHist
                    HistDisplay(HistAxis,HistAxisPosition);
                end
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(Channel_sld, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        function ChannelDown
            BufferViewerImageAxes=horzcat(BufferViewerImageAxes,{ViewerImageAxis});
            BufferMaskAxes=horzcat(BufferMaskAxes,MaskAxes);
            BufferTileAxes=horzcat(BufferTileAxes,TileAxes);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if Channel>1
                Channel=Channel-1;
            elseif Channel==1
                Channel=Last_C;
            else
            end
            set(Channel_sld,'Value',Channel)
            set(ChannelPos,'String',num2str(Channel))
            set(ChannelLabelText,'String',Channel_Labels{Channel});
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(Channel_sld, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %UpdateDisplay
            set(ColorMapList,'Value',Channel_Info(Channel).DisplayColorMapIndex);
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            ColorBarDisplay(ViewerFig,ColorBarAxis,ColorBarAxisPosition);
            if Z_Projection&&~T_Projection
                set(LowDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(1)))
                set(HighDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)))
                warning off
                set(Low_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1))
                set(High_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                warning on
            elseif ~Z_Projection&&T_Projection
                set(LowDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(1)))
                set(HighDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(2)))
                warning off
                set(Low_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1))
                set(High_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                warning on
            elseif Z_Projection&&T_Projection
                error('Not Currently Possible')
            else
                set(LowDisp,'String',num2str(Channel_Info(Channel).Display_Limits(1)))
                set(HighDisp,'String',num2str(Channel_Info(Channel).Display_Limits(2)))
                warning off
                set(Low_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(1))
                set(High_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                warning on
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if ~RGB_Stack
                if T_Stack
                    TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                end
                if LiveHist
                    HistDisplay(HistAxis,HistAxisPosition);
                end
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(Channel_sld, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end  
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function InitializeDir
            SetUpDir=0;
            if isempty(ExportDir)||isempty(ScratchDir)
                SetUpDir=1;
            else
                SetUpDirChoice = questdlg({'Directories Exist Reuse?';['ExportDir=',ExportDir];['ScratchDir=',ScratchDir]},'Reuse Directory Choice?','Reuse','Set Up','Reuse');
                switch SetUpDirChoice
                    case 'Reuse'
                        SetUpDir=0;
                    case 'Set Up'
                        SetUpDir=1;
                end
            end
            if SetUpDir
                if ~isempty(ExportDir)
                    TempDir=ExportDir;
                else
                    TempDir=StartingDir;
                end
                if isempty(TempDir)
                    TempDir=cd;
                elseif ~ischar(TempDir)
                    if ~TempDir
                        TempDir=cd;
                    end
                end
                cd(TempDir);
                ExportDir=uigetdir(TempDir,['Please Select Export Destination Directory']);
                cd(ExportDir)
                ScratchChoice = questdlg('Do you want to save to a Scratch Directory First?','Scratch Dir?','Use Scratch','Skip','Use Scratch');
                switch ScratchChoice
                    case 'Use Scratch'
                        Save2Scratch=1;
                    case 'Skip'
                        Save2Scratch=0;
                end
                if Save2Scratch
                    if ~isempty(ScratchDir)
                        TempDir=ScratchDir;
                    else
                        TempDir=StartingDir;
                    end
                    cd(TempDir);
                    ScratchDir=uigetdir(StartingDir,['Please Select Temporary Scratch Destination Directory']);
                    cd(ScratchDir)
                    if strcmp(ScratchDir,ExportDir)
                        warning('Directories are the same!')
                        Save2Scratch=0;
                    end
                else
                    ScratchDir=ExportDir;
                end
            end
        end
        function StartParPool
            if exist('myPool')
                if ~isempty(myPool)
                    try
                        if isempty(myPool.IdleTimeout)
                            warning('Parpool timed out! Restarting now...')
                            delete(gcp('nocreate'))
                            myPool=parpool;%
                        else
                            disp('Parpool active...')
                        end
                    catch
                        warning('Problem with parpool trying again...')
                        delete(gcp('nocreate'))
                        myPool=parpool;
                    end
                else
                    warning('Restarting ParPool...')
                    delete(gcp('nocreate'))
                    myPool=parpool;
                end
            else
                warning('Restarting ParPool...')
                delete(gcp('nocreate'))
                myPool=parpool;
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function ExportImage(~,~,~)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ExportImageButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            ExportSettings.ExportMode=1;
            ExportPreparation;
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ExportImageButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        function ExportMovie(~,~,~)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ExportMovieButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            ExportSettings.ExportMode=2;
            ExportPreparation;
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ExportMovieButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function [CurrentPosition,CurrentLabel]=GetCurrentPosition(ImagingInfo,ChannelSettings,SliceSettings,FrameSettings,ImageLabel,c,c1,z,z1,t,t1)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if isempty(ChannelSettings)
                if c~=0&&c~=-1&&c~=-2
                    ChannelSettings.C_Display{c1}=Channel_Labels{c};
                elseif c==0
                    ChannelSettings.C_Display{c1}=['Merge'];
                elseif c==-1
                    if isempty(Z_ProjectionSettings.Z_ProjectionType)
                        ChannelSettings.C_Display{c1}=['Merge Z Proj'];
                    else
                        ChannelSettings.C_Display{c1}=['Merge ',Z_ProjectionSettings.Z_ProjectionType,' Z Proj'];
                    end
                elseif c==-2
                    if isempty(T_ProjectionSettings.T_ProjectionType)
                        ChannelSettings.C_Display{c1}=['Merge T Proj'];
                    else
                        ChannelSettings.C_Display{c1}=['Merge ',T_ProjectionSettings.T_ProjectionType,' T Proj'];
                    end
                end
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if isempty(SliceSettings)
                if z~=0
                    TempVoxel=num2str(ImagingInfo.VoxelDepth);
                    TempVoxDecimals=strfind(TempVoxel,'.');
                    TempZ=num2str(z);
                    if isempty(TempVoxDecimals)
                        TempZ=round((z-1)*ImagingInfo.VoxelDepth);
                        TempZ=num2str(TempZ);
                        TempZ=[TempZ];
                    elseif TempVoxDecimals==length(TempVoxel)-1
                        TempZ=round(z*ImagingInfo.VoxelDepth*10)/10;
                        TempZ=num2str(TempZ);
                        TempDecimals=strfind(TempZ,'.');
                        if isempty(TempDecimals)
                            TempZ=[TempZ,'.0'];
                        end
                    elseif TempVoxDecimals==length(TempVoxel)-2
                        TempZ=round((z-1)*ImagingInfo.VoxelDepth*100)/100;
                        TempZ=num2str(TempZ);
                        TempDecimals=strfind(TempZ,'.');
                        if isempty(TempDecimals)
                            TempZ=[TempZ,'.00'];
                        elseif TempDecimals==length(TempZ)-1
                            TempZ=[TempZ,'0'];
                        end
                    elseif TempVoxDecimals==length(TempVoxel)-3
                        TempZ=round((z-1)*ImagingInfo.VoxelDepth*1000)/1000;
                        TempZ=num2str(TempZ);
                        TempDecimals=strfind(TempZ,'.');
                        if isempty(TempDecimals)
                            TempZ=[TempZ,'.000'];
                        elseif TempDecimals==length(TempZ)-1
                            TempZ=[TempZ,'00'];
                        elseif TempDecimals==length(TempZ)-2
                            TempZ=[TempZ,'0'];
                        end
                    else
                        TempZ=round((z-1)*ImagingInfo.VoxelDepth*1000)/1000;
                        TempZ=num2str(TempZ);
                        TempDecimals=strfind(TempZ,'.');
                        if isempty(TempDecimals)
                            TempZ=[TempZ,'.000'];
                        elseif TempDecimals==length(TempZ)-1
                            TempZ=[TempZ,'00'];
                        elseif TempDecimals==length(TempZ)-2
                            TempZ=[TempZ,'0'];
                        end
                    end
                    if ~isempty(ImageLabel)
                        TempUnit=ImagingInfo.VoxelUnit;
                        if strcmp(TempUnit,'um')&&ForceGreekCharacter
                            TempUnit='\mum';
                        end
                        if isfield(ImageLabel,'ZStyle')
                            if ImageLabel.ZStyle==0
                                SliceSettings.Z_Display{z1}=['Z=',num2str(z),' ',TempZ,' ',TempUnit];
                            elseif ImageLabel.ZStyle==1
                                SliceSettings.Z_Display{z1}=['Z=',num2str(z)];
                            elseif ImageLabel.ZStyle==2
                                SliceSettings.Z_Display{z1}=[TempZ,' ',TempUnit];
                            end
                        end
                    end
                else
                    SliceSettings.Z_Display{z1}=[Z_ProjectionSettings.Z_ProjectionType,' Z Projection'];
                end
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if isempty(FrameSettings)
                if t~=0
                    if ~isnan(ImagingInfo.InterFrameTime)
                        TempFrameInterval=num2str(ImagingInfo.InterFrameTime);
                        TempFrameDecimals=strfind(TempFrameInterval,'.');
                        if isempty(TempFrameDecimals)
                            TempT=round((t-1)*ImagingInfo.InterFrameTime);
                            TempT=num2str(TempT);
                            TempT=[TempT];
                        elseif TempFrameDecimals==length(TempFrameInterval)-1
                            TempT=round((t-1)*ImagingInfo.InterFrameTime*10)/10;
                            TempT=num2str(TempT);
                            TempDecimals=strfind(TempT,'.');
                            if isempty(TempDecimals)
                                TempT=[TempT,'.0'];
                            end
                        elseif TempFrameDecimals==length(TempFrameInterval)-2
                            TempT=round((t-1)*ImagingInfo.InterFrameTime*100)/100;
                            TempT=num2str(TempT);
                            TempDecimals=strfind(TempT,'.');
                            if isempty(TempDecimals)
                                TempT=[TempT,'.00'];
                            elseif TempDecimals==length(TempT)-1
                                TempT=[TempT,'0'];
                            end
                        elseif TempFrameDecimals==length(TempFrameInterval)-3
                            TempT=round((t-1)*ImagingInfo.InterFrameTime*1000)/1000;
                            TempT=num2str(TempT);
                            TempDecimals=strfind(TempT,'.');
                            if isempty(TempDecimals)
                                TempT=[TempT,'.000'];
                            elseif TempDecimals==length(TempT)-1
                                TempT=[TempT,'00'];
                            elseif TempDecimals==length(TempT)-2
                                TempT=[TempT,'0'];
                            end
                        end
                        if ~isempty(ImageLabel)
                            if isfield(ImageLabel,'TStyle')
                                if ImageLabel.TStyle==0
                                    FrameSettings.T_Display{t1}=['T=',num2str(t),' ',TempT,ImagingInfo.FrameUnit];
                                elseif ImageLabel.TStyle==1
                                    FrameSettings.T_Display{t1}=['T=',num2str(t)];
                                elseif ImageLabel.TStyle==2
                                    FrameSettings.T_Display{t1}=[TempT,ImagingInfo.FrameUnit];
                                end
                            end
                        end
                    else
                        FrameSettings.T_Display{t1}=['T=',num2str(t)];
                    end
                else
                    FrameSettings.T_Display{t1}='T Projection';
                end
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            CurrentLabel=[];
            try
            if isempty(ImageLabel)
                ImageLabel.IncludeC=1;
                ImageLabel.IncludeZ=1;
                ImageLabel.IncludeT=1;
            end
            if C_Stack&&ImageLabel.IncludeC
                CurrentLabel=[CurrentLabel,ChannelSettings.C_Display{c1},' '];
%                 if c==-1
%                     CurrentLabel=[CurrentLabel,ChannelSettings.C_Display{c1},' '];%,FrameSettings.T_Display{t1}];
%                 elseif c==-2
%                     CurrentLabel=[CurrentLabel,ChannelSettings.C_Display{c1},' '];%,SliceSettings.Z_Display{z1}];
%                 else
%                     CurrentLabel=[CurrentLabel,ChannelSettings.C_Display{c1},' '];%,SliceSettings.Z_Display{z1},' ',FrameSettings.T_Display{t1}];
%                 end
            end
            if Z_Stack&&ImageLabel.IncludeZ&&c~=-1
                CurrentLabel=[CurrentLabel,SliceSettings.Z_Display{z1},' '];
            end
            if T_Stack&&ImageLabel.IncludeT&&c~=-2
                CurrentLabel=[CurrentLabel,FrameSettings.T_Display{t1},' '];
            end
            if ~isempty(CurrentLabel)
                CurrentLabel=CurrentLabel(1:length(CurrentLabel)-1);
            end
%             if C_Stack&&Z_Stack&&~T_Stack
%                 if c==-1
%                     CurrentLabel=[ChannelSettings.C_Display{c1}];
%                 elseif c==-2
%                     CurrentLabel=[ChannelSettings.C_Display{c1}];
%                 else
%                     CurrentLabel=[ChannelSettings.C_Display{c1},' ',SliceSettings.Z_Display{z1}];
%                 end
%             elseif C_Stack&&~Z_Stack&&T_Stack
%                 if c==-1
%                     CurrentLabel=[ChannelSettings.C_Display{c1}];
%                 elseif c==-2
%                     CurrentLabel=[ChannelSettings.C_Display{c1}];
%                 else
%                     CurrentLabel=[ChannelSettings.C_Display{c1},' ',FrameSettings.T_Display{t1}];
%                 end
%             elseif C_Stack&&~Z_Stack&&~T_Stack
%                 CurrentLabel=[ChannelSettings.C_Display{c1}];
%             elseif ~C_Stack&&Z_Stack&&T_Stack
%                 CurrentLabel=[SliceSettings.Z_Display{z1},' ',FrameSettings.T_Display{t1}];
%             elseif ~C_Stack&&Z_Stack&&~T_Stack
%                 CurrentLabel=[SliceSettings.Z_Display{z1}];
%             elseif ~C_Stack&&~Z_Stack&&T_Stack
%                 CurrentLabel=[FrameSettings.T_Display{t1}];
%             elseif ~C_Stack&&~Z_Stack&&~T_Stack
%                 CurrentLabel=[];
%             end
            catch
                warning('Problem updating label...')
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if c==0&&z~=0&&t~=0
                CurrentPosition.Channel=1;
                CurrentPosition.Frame=t;
                CurrentPosition.Slice=z;
                CurrentPosition.Z_Projection=0;
                CurrentPosition.T_Projection=0;
                CurrentPosition.MergeChannel=1;
                CurrentPosition.OverwriteMerge=0;
                CurrentPosition.TileChannels=0;
                CurrentPosition.TileSlices=0;
                CurrentPosition.TileFrames=0;
                CurrentPosition.TileSettings=0;
            elseif c==0&&z~=0&&t==0
                CurrentPosition.Channel=1;
                CurrentPosition.Frame=1;
                CurrentPosition.Slice=z;
                CurrentPosition.Z_Projection=0;
                CurrentPosition.T_Projection=1;
                CurrentPosition.MergeChannel=1;
                CurrentPosition.OverwriteMerge=0;
                CurrentPosition.TileChannels=0;
                CurrentPosition.TileSlices=0;
                CurrentPosition.TileFrames=0;
                CurrentPosition.TileSettings=0;
            elseif c>0&&z==0&&t~=0
                CurrentPosition.Channel=c;
                CurrentPosition.Frame=t;
                CurrentPosition.Slice=1;
                CurrentPosition.Z_Projection=1;
                CurrentPosition.T_Projection=0;
                CurrentPosition.MergeChannel=0;
                CurrentPosition.OverwriteMerge=0;
                CurrentPosition.TileChannels=0;
                CurrentPosition.TileSlices=0;
                CurrentPosition.TileFrames=0;
                CurrentPosition.TileSettings=0;
            elseif c>0&&z~=0&&t==0
                CurrentPosition.Channel=c;
                CurrentPosition.Frame=1;
                CurrentPosition.Slice=z;
                CurrentPosition.Z_Projection=0;
                CurrentPosition.T_Projection=1;
                CurrentPosition.MergeChannel=0;
                CurrentPosition.OverwriteMerge=0;
                CurrentPosition.TileChannels=0;
                CurrentPosition.TileSlices=0;
                CurrentPosition.TileFrames=0;
                CurrentPosition.TileSettings=0;
            elseif c==0&&z==0&&t~=0
                CurrentPosition.Channel=1;
                CurrentPosition.Frame=t;
                CurrentPosition.Slice=1;
                CurrentPosition.Z_Projection=1;
                CurrentPosition.T_Projection=0;
                CurrentPosition.MergeChannel=0;
                CurrentPosition.OverwriteMerge=0;
                CurrentPosition.TileChannels=0;
                CurrentPosition.TileSlices=0;
                CurrentPosition.TileFrames=0;
                CurrentPosition.TileSettings=0;
            elseif c==0&&z~=0&&t==0
                CurrentPosition.Channel=1;
                CurrentPosition.Frame=1;
                CurrentPosition.Slice=z;
                CurrentPosition.Z_Projection=1;
                CurrentPosition.T_Projection=1;
                CurrentPosition.MergeChannel=0;
                CurrentPosition.OverwriteMerge=0;
                CurrentPosition.TileChannels=0;
                CurrentPosition.TileSlices=0;
                CurrentPosition.TileFrames=0;
                CurrentPosition.TileSettings=0;
            elseif c==-1
                CurrentPosition.Channel=1;
                CurrentPosition.Frame=t;
                CurrentPosition.Slice=1;
                CurrentPosition.Z_Projection=1;
                CurrentPosition.T_Projection=0;
                CurrentPosition.MergeChannel=1;
                CurrentPosition.OverwriteMerge=0;
                CurrentPosition.TileChannels=0;
                CurrentPosition.TileSlices=0;
                CurrentPosition.TileFrames=0;
                CurrentPosition.TileSettings=0;
            elseif c==-2
                CurrentPosition.Channel=1;
                CurrentPosition.Frame=1;
                CurrentPosition.Slice=z;
                CurrentPosition.Z_Projection=0;
                CurrentPosition.T_Projection=1;
                CurrentPosition.MergeChannel=1;
                CurrentPosition.OverwriteMerge=0;
                CurrentPosition.TileChannels=0;
                CurrentPosition.TileSlices=0;
                CurrentPosition.TileFrames=0;
                CurrentPosition.TileSettings=0;
            else
                CurrentPosition.Channel=c;
                CurrentPosition.Frame=t;
                CurrentPosition.Slice=z;
                CurrentPosition.Z_Projection=0;
                CurrentPosition.T_Projection=0;
                CurrentPosition.MergeChannel=0;
                CurrentPosition.OverwriteMerge=0;
                CurrentPosition.TileChannels=0;
                CurrentPosition.TileSlices=0;
                CurrentPosition.TileFrames=0;
                CurrentPosition.TileSettings=0;
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function ExportPreparation
            %try
                TempTileChannels=TileChannels;
                TempTileSlices=TileSlices;
                TempTileFrames=TileFrames;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                TileChannels=0;
                TileSlices=0;
                TileFrames=0;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                ExportSetup=1;
                while ExportSetup
                    if isfield(ExportSettings,'ScaleFactor')
                        ExportSettings.PreviousScaleFactor=ExportSettings.ScaleFactor;
                    else
                        ExportSettings.PreviousScaleFactor=0;
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    if isempty(ImagingInfo)
                        CollectImagingInfo
                    end
                    if ScaleBarOn
                        TempChoice = questdlg({'Adjust Scale Bar?'},'Adjust Scale Bar?','Good','Adjust','Remove','Good');
                        switch TempChoice
                            case 'Adjust'
                                AdjustScaleBar=1;
                            case 'Good'
                                AdjustScaleBar=0;
                            case 'Remove'
                                ScaleBarOn=0;
                        end
                    else
                        TempChoice = questdlg({'Add Scale Bar?'},'Add Scale Bar?','Add','Skip','Add');
                        switch TempChoice
                            case 'Add'
                                AdjustScaleBar=1;
                            case 'Skip'
                                AdjustScaleBar=0;
                        end
                    end
                    if AdjustScaleBar
                        set(ScaleBarButton,'value',1)
                        AddScaleBar
                    end
                    if ImageLabelOn
                        TempChoice = questdlg({'Adjust Image Label?'},'Adjust Image Label?','Good','Adjust','Remove','Good');
                        switch TempChoice
                            case 'Adjust'
                                AdjustImageLabel=1;
                            case 'Good'
                                AdjustImageLabel=0;
                            case 'Remove'
                                ImageLabelOn=0;
                        end
                    else
                        TempChoice = questdlg({'Add Image Label?'},'Add Image Label?','Add','Skip','Add');
                        switch TempChoice
                            case 'Add'
                                AdjustImageLabel=1;
                            case 'Skip'
                                AdjustImageLabel=0;
                        end
                    end
                    if AdjustImageLabel
                        ImageLabelOn=1;
                        set(ImageLabelButton,'value',ImageLabelOn);
                        AddImageLabel
                    end
                    TempChannel=Channel;
                    TempMergeChannel=MergeChannel;
                    if ColorBarOverlayOn
                        if TempMergeChannel
                            MergeChannel=0;
                            Channel=1;
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        end
                        TempChoice = questdlg({'Adjust ColorBar Overlay?'},'Adjust ColorBar Overlay?','Good','Adjust','Remove','Good');
                        switch TempChoice
                            case 'Adjust'
                                AdjustColorBarOverlay=1;
                            case 'Good'
                                AdjustColorBarOverlay=0;
                            case 'Remove'
                                ColorBarOverlayOn=0;
                        end
                    else
                        TempChoice = questdlg({'Add ColorBar Overlay?'},'Add ColorBar Overlay?','Add','Skip','Add');
                        switch TempChoice
                            case 'Add'
                                AdjustColorBarOverlay=1;
                            case 'Skip'
                                AdjustColorBarOverlay=0;
                        end
                    end
                    if AdjustColorBarOverlay
                        ColorBarOverlayOn=1;
                        set(ColorBarOverlayButton,'value',ColorBarOverlayOn);
                        AddColorBarOverlay
                    end
                    if TempMergeChannel
                        MergeChannel=TempMergeChannel;
                        Channel=TempChannel;
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                        [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    InitializeDir
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    switch ExportSettings.ExportMode
                        case 1
                            ExportSettings.ExportFormatOptions={'.eps','.pdf'};
                            ExportSettings.ExportFormats=[1,2];
                            ExportSettings.ExportStyleOptions={...
                                'Current Image',...
                                'Vert C Horz Z',...
                                'Vert Z Horz C',...
                                'Tile C',...
                                'Tile Z',...
                                'Tile T'};
                            if ~isfield(ExportSettings,'ExportStyle')
                                ExportSettings.ExportStyle=1;
                                if Z_Stack&&T_Stack&&C_Stack
                                    ExportSettings.ExportStyle=1;
                                elseif Z_Stack&&~T_Stack&&C_Stack
                                    ExportSettings.ExportStyle=1;
                                elseif ~Z_Stack&&T_Stack&&C_Stack
                                    ExportSettings.ExportStyle=1;
                                elseif Z_Stack&&T_Stack&&~C_Stack
                                    ExportSettings.ExportStyle=1;
                                else
                                    ExportSettings.ExportStyle=1;
                                end
                            end
                            if isempty(ExportSettings.ExportStyle)
                                ExportSettings.ExportStyle=1;
                            end
                            if ExportSettings.ExportStyle>length(ExportSettings.ExportStyleOptions)
                                ExportSettings.ExportStyle=1;
                            end
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                            [ExportSettings.ExportStyle, checking] = listdlg('PromptString',{'Select Export Layout'},...
                                'SelectionMode','single','ListString',ExportSettings.ExportStyleOptions,'ListSize', [200 200],'InitialValue',ExportSettings.ExportStyle);
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                            if any(ExportSettings.ExportStyle==[2,3,4])
                                [ExportSettings]=ChannelSelection(ExportSettings);
                            else
                                if MergeChannel
                                    ExportSettings.C_Range=0;
                                else
                                    ExportSettings.C_Range=Channel;
                                end
                            end
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                            if any(ExportSettings.ExportStyle==[2,3,5])
                                [ExportSettings]=SliceSelection(ExportSettings);
                            else
                                if Z_Projection&&~MergeChannel
                                    ExportSettings.Z_Range=0;
                                elseif Z_Projection&&MergeChannel
                                    ExportSettings.Z_Range=0;
                                    ExportSettings.C_Range=-1;
                                else
                                    ExportSettings.Z_Range=Slice;
                                end
                            end
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                            if any(ExportSettings.ExportStyle==[6])
                                [ExportSettings]=FrameSelection(ExportSettings);
                            else
                                if T_Projection&&~MergeChannel
                                    ExportSettings.T_Range=0;
                                elseif T_Projection&&MergeChannel
                                    ExportSettings.T_Range=0;
                                    ExportSettings.C_Range=-2;
                                else
                                    ExportSettings.T_Range=Frame;
                                end
                            end
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                            ExportSettings.ImageExportName=[ExportSettings.ImageName];
                            if ZoomOn
                                ExportSettings.ImageExportName=[ExportSettings.ImageExportName,' ','Zoom'];
                            end
                            switch ExportSettings.ExportStyle
                                case 1
                                    if C_Stack
                                        ExportSettings.ImageExportName=[ExportSettings.ImageExportName,' C',num2str(ExportSettings.C_Range)];
                                    end
                                    if Z_Stack
                                        ExportSettings.ImageExportName=[ExportSettings.ImageExportName,' Z',num2str(ExportSettings.Z_Range)];
                                    end
                                    if T_Stack
                                        ExportSettings.ImageExportName=[ExportSettings.ImageExportName,' T',num2str(ExportSettings.T_Range)];
                                    end
                                case 2
                                    ExportSettings.ImageExportName=[ExportSettings.ImageExportName,...
                                        ' C'];
                                    for ccc=1:length(ExportSettings.C_Range)
                                        ExportSettings.ImageExportName=[ExportSettings.ImageExportName,...
                                            '_',num2str(ExportSettings.C_Range(ccc))];
                                    end
                                    ExportSettings.ImageExportName=[ExportSettings.ImageExportName,...
                                        ' Z',num2str(ExportSettings.Z_Range(1)),'_',num2str(ExportSettings.Z_Range(length(ExportSettings.Z_Range)))];
                                     if T_Stack
                                        ExportSettings.ImageExportName=[ExportSettings.ImageExportName,' T',num2str(ExportSettings.T_Range)];
                                     end
                                case 3
                                    ExportSettings.ImageExportName=[ExportSettings.ImageExportName,...
                                        ' C'];
                                    for ccc=1:length(ExportSettings.C_Range)
                                        ExportSettings.ImageExportName=[ExportSettings.ImageExportName,...
                                            '_',num2str(ExportSettings.C_Range(ccc))];
                                    end
                                    ExportSettings.ImageExportName=[ExportSettings.ImageExportName,...
                                        ' Z',num2str(ExportSettings.Z_Range(1)),'_',num2str(ExportSettings.Z_Range(length(ExportSettings.Z_Range)))];
                                    if T_Stack
                                        ExportSettings.ImageExportName=[ExportSettings.ImageExportName,' T',num2str(ExportSettings.T_Range)];
                                    end
                                case 4
                                    ExportSettings.ImageExportName=[ExportSettings.ImageExportName,...
                                        ' C'];
                                    for ccc=1:length(ExportSettings.C_Range)
                                        ExportSettings.ImageExportName=[ExportSettings.ImageExportName,...
                                            '_',num2str(ExportSettings.C_Range(ccc))];
                                    end
                                    if Z_Stack
                                        ExportSettings.ImageExportName=[ExportSettings.ImageExportName,' Z',num2str(ExportSettings.Z_Range)];
                                    end
                                    if T_Stack
                                        ExportSettings.ImageExportName=[ExportSettings.ImageExportName,' T',num2str(ExportSettings.T_Range)];
                                    end
                                case 5
                                    if C_Stack
                                        ExportSettings.ImageExportName=[ExportSettings.ImageExportName,' C',num2str(ExportSettings.C_Range)];
                                    end
                                    ExportSettings.ImageExportName=[ExportSettings.ImageExportName,...
                                        ' Z',num2str(ExportSettings.Z_Range(1)),'_',num2str(ExportSettings.Z_Range(length(ExportSettings.Z_Range)))];
                                    if T_Stack
                                        ExportSettings.ImageExportName=[ExportSettings.ImageExportName,' T',num2str(ExportSettings.T_Range)];
                                    end
                                case 6
                                    if C_Stack
                                        ExportSettings.ImageExportName=[ExportSettings.ImageExportName,' C',num2str(ExportSettings.C_Range)];
                                    end
                                    ExportSettings.ImageExportName=[ExportSettings.ImageExportName,...
                                        ' T',num2str(ExportSettings.Z_Range(1)),'_',num2str(ExportSettings.Z_Range(length(ExportSettings.Z_Range)))];
                                    if Z_Stack
                                        ExportSettings.ImageExportName=[ExportSettings.ImageExportName,' Z',num2str(ExportSettings.Z_Range)];
                                    end
                            end
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        case 2
                            ExportSettings.ExportFormatOptions={'.avi'};
                            ExportSettings.ExportFormats=[1];
                            ExportSettings.ExportStyleOptions={...
                                'Current Play T',...
                                'Vert C Horz Z Play T',...
                                'Vert Z Horz C Play T',...
                                'Tile C Play T (Current Z)',...
                                'Tile Z Play T (Current C)',...
                                'Tile Z Play C',...
                                'Tile C Play Z'...
                                };
                            if ~isfield(ExportSettings,'ExportStyle')
                                ExportSettings.ExportStyle=1;
                                if Z_Stack&&T_Stack&&C_Stack
                                    ExportSettings.ExportStyle=2;
                                elseif Z_Stack&&~T_Stack&&C_Stack
                                    ExportSettings.ExportStyle=7;
                                elseif ~Z_Stack&&T_Stack&&C_Stack
                                    ExportSettings.ExportStyle=4;
                                elseif Z_Stack&&T_Stack&&~C_Stack
                                    ExportSettings.ExportStyle=5;
                                else
                                    ExportSettings.ExportStyle=1;
                                end
                            end
                            if isempty(ExportSettings.ExportStyle)
                                ExportSettings.ExportStyle=1;
                            end
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                            [ExportSettings.ExportStyle, checking] = listdlg('PromptString',{'Select Export Layout'},...
                                'SelectionMode','single','ListString',ExportSettings.ExportStyleOptions,'ListSize', [200 200],'InitialValue',ExportSettings.ExportStyle);
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                            if any(ExportSettings.ExportStyle==[2,3,4,6,7])
                                [ExportSettings]=ChannelSelection(ExportSettings);
                            else
                                ExportSettings.C_Range=Channel;
                            end
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                            if any(ExportSettings.ExportStyle==[2,3,5,6,7])
                                [ExportSettings]=SliceSelection(ExportSettings);
                            else
                                ExportSettings.Z_Range=Slice;
                            end
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                            if any(ExportSettings.ExportStyle==[1,2,3,4,5])
                                [ExportSettings]=FrameSelection(ExportSettings);
                            else
                                ExportSettings.T_Range=Frame;
                            end
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    GoodPanels=0;
                    while ~GoodPanels
                        ExportSettings.ExportIncludeTrace=0;
                        switch ExportSettings.ExportStyle
                            case 1
                                ExportSettings.NumColumns=1;
                                ExportSettings.NumRows=1;
                                ExportSettings.TotalPanels=1;
                            case 2
                                ExportSettings.NumColumns=length(ExportSettings.Z_Range);
                                ExportSettings.NumRows=length(ExportSettings.C_Range);
                                ExportSettings.TotalPanels=length(ExportSettings.Z_Range)*length(ExportSettings.C_Range);
                            case 3
                                ExportSettings.NumColumns=length(ExportSettings.C_Range);
                                ExportSettings.NumRows=length(ExportSettings.Z_Range);
                                ExportSettings.TotalPanels=length(ExportSettings.Z_Range)*length(ExportSettings.C_Range);
                            case 4
                                if ~isfield(ExportSettings,'NumColumns')
                                    if length(ExportSettings.C_Range)<=4
                                        ExportSettings.NumColumns = length(ExportSettings.C_Range);
                                        ExportSettings.NumRows    = 1;
                                    elseif length(ExportSettings.C_Range)<=8
                                        ExportSettings.NumColumns = ceil(length(ExportSettings.C_Range)/2);
                                        ExportSettings.NumRows    = 2;
                                    else
                                        ExportSettings.NumColumns = ceil(length(ExportSettings.C_Range)/3);
                                        ExportSettings.NumRows    = 3;
                                    end
                                end
                                prompt = {  ['NumColumns (Total ',num2str(length(ExportSettings.C_Range)),')'],...
                                            ['NumRows (Total ',num2str(length(ExportSettings.C_Range)),')']};
                                dlg_title = 'Export Layout';
                                num_lines = 1;
                                def = {num2str(ExportSettings.NumColumns),num2str(ExportSettings.NumRows)};
                                answer = inputdlg(prompt,dlg_title,num_lines,def);
                                ExportSettings.NumColumns= str2num(answer{1});
                                ExportSettings.NumRows=    str2num(answer{2});
                                clear answer
                                ExportSettings.TotalPanels=length(ExportSettings.C_Range);
                            case 5
                                if ~isfield(ExportSettings,'NumColumns')
                                    if length(ExportSettings.Z_Range)<=4
                                        ExportSettings.NumColumns = length(ExportSettings.Z_Range);
                                        ExportSettings.NumRows    = 1;
                                    elseif length(ExportSettings.Z_Range)<=8
                                        ExportSettings.NumColumns = ceil(length(ExportSettings.Z_Range)/2);
                                        ExportSettings.NumRows    = 2;
                                    else
                                        ExportSettings.NumColumns = ceil(length(ExportSettings.Z_Range)/3);
                                        ExportSettings.NumRows    = 3;
                                    end
                                end
                                prompt = {  ['NumColumns (Total ',num2str(length(ExportSettings.Z_Range)),')'],...
                                            ['NumRows (Total ',num2str(length(ExportSettings.Z_Range)),')']};
                                dlg_title = 'Export Layout';
                                num_lines = 1;
                                def = {num2str(ExportSettings.NumColumns),num2str(ExportSettings.NumRows)};
                                answer = inputdlg(prompt,dlg_title,num_lines,def);
                                ExportSettings.NumColumns= str2num(answer{1});
                                ExportSettings.NumRows=    str2num(answer{2});
                                clear answer
                                ExportSettings.TotalPanels=length(ExportSettings.Z_Range);
                            case 6
                                if ~isfield(ExportSettings,'NumColumns')
                                    if length(ExportSettings.Z_Range)<=4
                                        ExportSettings.NumColumns = length(ExportSettings.Z_Range);
                                        ExportSettings.NumRows    = 1;
                                    elseif length(ExportSettings.Z_Range)<=8
                                        ExportSettings.NumColumns = ceil(length(ExportSettings.Z_Range)/2);
                                        ExportSettings.NumRows    = 2;
                                    else
                                        ExportSettings.NumColumns = ceil(length(ExportSettings.Z_Range)/3);
                                        ExportSettings.NumRows    = 3;
                                    end
                                end
                                prompt = {  ['NumColumns (Total ',num2str(length(ExportSettings.Z_Range)),')'],...
                                            ['NumRows (Total ',num2str(length(ExportSettings.Z_Range)),')']};
                                dlg_title = 'Export Layout';
                                num_lines = 1;
                                def = {num2str(ExportSettings.NumColumns),num2str(ExportSettings.NumRows)};
                                answer = inputdlg(prompt,dlg_title,num_lines,def);
                                ExportSettings.NumColumns= str2num(answer{1});
                                ExportSettings.NumRows=    str2num(answer{2});
                                clear answer
                                ExportSettings.TotalPanels=length(ExportSettings.Z_Range);
                            case 7
                                if ~isfield(ExportSettings,'NumColumns')
                                    if length(ExportSettings.C_Range)<=4
                                        ExportSettings.NumColumns = length(ExportSettings.C_Range);
                                        ExportSettings.NumRows    = 1;
                                    elseif length(ExportSettings.C_Range)<=8
                                        ExportSettings.NumColumns = ceil(length(ExportSettings.C_Range)/2);
                                        ExportSettings.NumRows    = 2;
                                    else
                                        ExportSettings.NumColumns = ceil(length(ExportSettings.C_Range)/3);
                                        ExportSettings.NumRows    = 3;
                                    end
                                end
                                prompt = {  ['NumColumns (Total ',num2str(length(ExportSettings.C_Range)),')'],...
                                            ['NumRows (Total ',num2str(length(ExportSettings.C_Range)),')']};
                                dlg_title = 'Export Layout';
                                num_lines = 1;
                                def = {num2str(ExportSettings.NumColumns),num2str(ExportSettings.NumRows)};
                                answer = inputdlg(prompt,dlg_title,num_lines,def);
                                ExportSettings.NumColumns= str2num(answer{1});
                                ExportSettings.NumRows=    str2num(answer{2});
                                clear answer
                                ExportSettings.TotalPanels=length(ExportSettings.C_Range);
                        end
                        if ~isfield(ExportSettings,'PanelOrder')
                            ExportSettings.PanelOrder='Horizontal';
                        end
                        if ExportSettings.NumColumns==1&&ExportSettings.NumRows~=1
                            ExportSettings.PanelOrder='Vertical';
                        elseif ExportSettings.NumColumns~=1&&ExportSettings.NumRows==1
                            ExportSettings.PanelOrder='Horizontal';
                        elseif ExportSettings.NumColumns==1&&ExportSettings.NumRows==1
                            ExportSettings.PanelOrder='Horizontal';
                        else
                            ExportSettings.PanelOrder='Horizontal';
                        end
                        ExportSettings.PanelOrder = questdlg({'What Direction to Fill Panels?'},'Panel Order?','Horizontal','Vertical',ExportSettings.PanelOrder);
                        if T_Stack
                            ExportIncludeTraceChoice = questdlg({'I can add the current traces to the export';...
                                'Do you want me to include?'},'Include Traces?','Yes Row','Yes Col','No',ExportIncludeTraceChoice);
                            if ~isfield(ExportSettings,'SplitTraceAdjust')
                                ExportSettings.SplitTraceAdjust=0;
                            end
                            switch ExportIncludeTraceChoice
                                case 'Yes Row'
                                    ExportSettings.ExportIncludeTrace=1;
                                    if ~isfield(ExportSettings,'TraceChannel')
                                        ExportSettings.TraceChannel=Channel;
                                    end
                                    prompt = {'Number of Rows for Trace to Occupy (>0)',...
                                        'Vert Trace Split (0 for overlay)',...
                                        ['Trace Channel Data (',num2str([1:Last_C]),')']};
                                    dlg_title = 'Trace Settings';
                                    num_lines = 1;
                                    def = {num2str(ExportSettings.ExportIncludeTraceNum),num2str(ExportSettings.SplitTraceAdjust),num2str(ExportSettings.TraceChannel)};
                                    answer = inputdlg(prompt,dlg_title,num_lines,def);
                                    ExportSettings.ExportIncludeTraceNum=str2num(answer{1});
                                    ExportSettings.SplitTraceAdjust=str2num(answer{2});
                                    ExportSettings.TraceChannel=str2num(answer{3});
                                    clear answer
                                case 'Yes Col'
                                    ExportSettings.ExportIncludeTrace=2;
                                    if ~isfield(ExportSettings,'TraceChannel')
                                        ExportSettings.TraceChannel=Channel;
                                    end
                                    prompt = {'Number of Columns for Trace to Occupy (>0)',...
                                        'Vert Trace Split (0 for overlay)',...
                                        ['Trace Channel Data (',num2str([1:Last_C]),')']};
                                    dlg_title = 'Trace Settings';
                                    num_lines = 1;
                                    def = {num2str(ExportSettings.ExportIncludeTraceNum),num2str(ExportSettings.SplitTraceAdjust),num2str(ExportSettings.TraceChannel)};
                                    answer = inputdlg(prompt,dlg_title,num_lines,def);
                                    ExportSettings.ExportIncludeTraceNum=str2num(answer{1});
                                    ExportSettings.SplitTraceAdjust=str2num(answer{2});
                                    ExportSettings.TraceChannel=str2num(answer{3});
                                    clear answer
                                case 'No'
                                    ExportSettings.ExportIncludeTrace=0;
                            end
                            if ExportSettings.ExportIncludeTrace>0
                                if TraceScaleOn
                                    TempChoice = questdlg({'Adjust Trace Scale Bars?'},'Trace Scale Bars?','Good','Adjust','Remove','Good');
                                    switch TempChoice
                                        case 'Adjust'
                                            AdjustTraceScale=1;
                                        case 'Good'
                                            AdjustTraceScale=0;
                                        case 'Remove'
                                            TraceScaleOn=0;
                                    end
                                else
                                    TempChoice = questdlg({'Add Trace Scale Bars?'},'Add Trace Scale Bars?','Add','Skip','Add');
                                    switch TempChoice
                                        case 'Add'
                                            AdjustTraceScale=1;
                                        case 'Skip'
                                            AdjustTraceScale=0;
                                    end
                                end
                                if AdjustTraceScale
                                    TraceScaleOn = 1;
                                    set(TraceScaleButton,'value',1);
                                    TraceScaleBar;
                                end
                            end
                        end
                        if ExportSettings.ExportIncludeTrace>0
                            ExportSettings.TraceSliceSelection.Z_Range=ExportSettings.Z_Range;
                        end
                        ExportSettings.PrimaryNumRows=ExportSettings.NumRows;
                        ExportSettings.PrimaryNumColumns=ExportSettings.NumColumns;
                        if ExportSettings.ExportIncludeTrace==1
                            ExportSettings.NumRows=ExportSettings.NumRows+ExportSettings.ExportIncludeTraceNum;
                        elseif ExportSettings.ExportIncludeTrace==2
                            ExportSettings.NumColumns=ExportSettings.NumColumns+ExportSettings.ExportIncludeTraceNum;
                        end
                        ExportSettings.PanelWidth=1/ExportSettings.NumColumns;
                        ExportSettings.PanelHeight=1/ExportSettings.NumRows;
                        ExportSettings.ExportMaskAxes=[];
                        ExportSettings.ExportTileAxes=[];
                        PanelCount=0;
                        switch ExportSettings.PanelOrder
                            case 'Horizontal'
                                for row=1:ExportSettings.PrimaryNumRows
                                    for col=1:ExportSettings.PrimaryNumColumns
                                        PanelCount=PanelCount+1;
                                        ExportSettings.PanelAxes(PanelCount).Axis=...
                                            [(col-1)*ExportSettings.PanelWidth,...
                                            1-(row)*ExportSettings.PanelHeight,...
                                            ExportSettings.PanelWidth,...
                                            ExportSettings.PanelHeight];
                                    end
                                end
                            case 'Vertical'
                                for col=1:ExportSettings.PrimaryNumColumns
                                    for row=1:ExportSettings.PrimaryNumRows
                                        PanelCount=PanelCount+1;
                                        ExportSettings.PanelAxes(PanelCount).Axis=...
                                            [(col-1)*ExportSettings.PanelWidth,...
                                            1-(row)*ExportSettings.PanelHeight,...
                                            ExportSettings.PanelWidth,...
                                            ExportSettings.PanelHeight];
                                    end
                                end
                        end
                        if ExportSettings.ExportIncludeTrace==1
                            ExportSettings.TraceAxis(1)=TraceAxisPosition(1);
                            ExportSettings.TraceAxis(2)=TraceAxisPosition(2)*2;
                            ExportSettings.TraceAxis(3)=TraceAxisPosition(3);
                            ExportSettings.TraceAxis(4)=ExportSettings.PanelHeight*ExportSettings.ExportIncludeTraceNum-TraceAxisPosition(2)*2;
                        elseif ExportSettings.ExportIncludeTrace==2
                            ExportSettings.TraceAxis(1)=ExportSettings.PanelWidth*(ExportSettings.NumColumns-ExportSettings.ExportIncludeTraceNum)+TraceAxisPosition(1);
                            ExportSettings.TraceAxis(2)=TraceAxisPosition(2);
                            ExportSettings.TraceAxis(3)=ExportSettings.PanelWidth*ExportSettings.ExportIncludeTraceNum-TraceAxisPosition(1)*2;
                            ExportSettings.TraceAxis(4)=1-TraceAxisPosition(2)*2;
                        end
                        if ExportSettings.PreviousScaleFactor~=ExportSettings.ScaleFactor||~isfield(ExportSettings,'ExportSize')
                            if ZoomOn
                                ExportSettings.ExportSize=[ ZoomDataRegion_Props.BoundingBox(3)*ExportSettings.NumColumns*ExportSettings.ScaleFactor,...
                                                            ZoomDataRegion_Props.BoundingBox(4)*ExportSettings.NumRows*ExportSettings.ScaleFactor];
                            else
                                ExportSettings.ExportSize=[ ImageWidth*ExportSettings.NumColumns*ExportSettings.ScaleFactor,...
                                                            ImageHeight*ExportSettings.NumRows*ExportSettings.ScaleFactor];
                            end
                        end
                        if ExportSettings.PreviousScaleFactor~=ExportSettings.ScaleFactor||~isfield(ExportSettings,'ExportPosition')
                            ExportSettings.ExportPosition=[0,0];
                        end
                        if PanelCount<ExportSettings.TotalPanels
                            warning('Not Enough Panels Allocated')
                            GoodPanels=0;
                        else
                            GoodPanels=1;
                        end
                        if ExportSettings.ExportIncludeTrace==1
                            ExportSettings.NumRows=ExportSettings.NumRows-ExportSettings.ExportIncludeTraceNum;
                        elseif ExportSettings.ExportIncludeTrace==2
                            ExportSettings.NumColumns=ExportSettings.NumColumns-ExportSettings.ExportIncludeTraceNum;
                        end
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  
                    if ExportSettings.ExportSize(2)>ScreenSize(4)-100
                        ExportScalarModifier=(ScreenSize(4)-100)/ExportSettings.ExportSize(2);
                        warning(['Adjusting Vertical ExportSize by ',num2str(ExportScalarModifier),' to fit Monitor!'])
                        ExportSettings.ExportSize=round(ExportSettings.ExportSize*ExportScalarModifier);
                    end
                    if ExportSettings.ExportSize(1)>ScreenSize(3)
                        ExportScalarModifier=ScreenSize(3)/ExportSettings.ExportSize(1);
                        warning(['Adjusting Horizontal ExportSize by ',num2str(ExportScalarModifier),' to fit Monitor!'])
                        ExportSettings.ExportSize=round(ExportSettings.ExportSize*ExportScalarModifier);
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    SizingExportChoice = questdlg({'Reset Export Size to Defaults will rescale to optimal'},'Reset Export Size?','Skip','Reset','Reset');
                    switch SizingExportChoice
                        case 'Reset'
                            if ZoomOn
                                ExportSettings.ExportSize=[ ZoomDataRegion_Props.BoundingBox(3)*ExportSettings.NumColumns*ExportSettings.ScaleFactor,...
                                                            ZoomDataRegion_Props.BoundingBox(4)*ExportSettings.NumRows*ExportSettings.ScaleFactor];
                            else
                                ExportSettings.ExportSize=[ ImageWidth*ExportSettings.NumColumns*ExportSettings.ScaleFactor,...
                                                            ImageHeight*ExportSettings.NumRows*ExportSettings.ScaleFactor];
                            end
                            ExportSettings.ExportPosition=[0,0];
                            if ExportSettings.ExportSize(2)>ScreenSize(4)-100
                                ExportScalarModifier=(ScreenSize(4)-100)/ExportSettings.ExportSize(2);
                                warning(['Adjusting Vertical ExportSize by ',num2str(ExportScalarModifier),' to fit Monitor!'])
                                ExportSettings.ExportSize=round(ExportSettings.ExportSize*ExportScalarModifier);
                            end
                            if ExportSettings.ExportSize(1)>ScreenSize(3)
                                ExportScalarModifier=ScreenSize(3)/ExportSettings.ExportSize(1);
                                warning(['Adjusting Horizontal ExportSize by ',num2str(ExportScalarModifier),' to fit Monitor!'])
                                ExportSettings.ExportSize=round(ExportSettings.ExportSize*ExportScalarModifier);
                            end
                            ExportSettings.ExportSizeRatio=ExportSettings.ExportSize(1)/ExportSettings.ExportSize(2);
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    ExportSettings.ExportSizeRatio=ExportSettings.ExportSize(1)/ExportSettings.ExportSize(2);
                    ExportFig=figure;
                    set(ExportFig,'units','Pixels','position',[ExportSettings.ExportPosition,ExportSettings.ExportSize]);
                    set(ExportFig, 'color', 'white');
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    if ScaleBarOn
                        if ~ZoomOn
                            if ~isfield(ExportSettings,'ScaleBarExportFontSize')
                                ExportSettings.ScaleBarExportFontSize=ScaleBar.FontSize;
                            end
                        else
                            if ~isfield(ExportSettings,'ScaleBarExportFontSize')
                                ExportSettings.ScaleBarExportFontSize=ZoomScaleBar.FontSize;
                            end
                        end
                    end
                    if ImageLabelOn
                        if ~ZoomOn
                            if ~isfield(ExportSettings,'ImageLabelExportFontSize')
                                ExportSettings.ImageLabelExportFontSize=ImageLabel.FontSize;
                            end
                        else
                            if ~isfield(ExportSettings,'ImageLabelExportFontSize')
                                ExportSettings.ImageLabelExportFontSize=ZoomImageLabel.FontSize;
                            end
                        end
                    end
                    if ColorBarOverlayOn
                        if ~isfield(ExportSettings,'ColorBarExportFontSize')
                            ExportSettings.ColorBarExportFontSize=ColorBarOverlay.FontSize;
                        end
                    end
                    SizingExport=1;
                    while SizingExport
                        prompt = {'Export Width (px) NOTE: 0 will scale to Height','Export Height (px) NOTE: 0 will scale to Width',...
                            'Export Horz (lower left px) Position','Export Vert (lower left px) Position'};
                        dlg_title = 'Export Sizes';
                        num_lines = 1;
                        def = {num2str(ExportSettings.ExportSize(1)),num2str(ExportSettings.ExportSize(2)),...
                            num2str(ExportSettings.ExportPosition(1)),num2str(ExportSettings.ExportPosition(2))};
                        if ScaleBarOn
                            ScaleBarPos=length(prompt)+1;
                            prompt=horzcat(prompt,{'ScaleBar Font Size'});
                            def=horzcat(def,{num2str(ExportSettings.ScaleBarExportFontSize)});
                        end
                        if ImageLabelOn
                            ImageLabelPos=length(prompt)+1;
                            prompt=horzcat(prompt,{'ImageLabel Font Size'});
                            def=horzcat(def,{num2str(ExportSettings.ImageLabelExportFontSize)});
                        end
                        if ColorBarOverlayOn
                            ColorBarLabelPos=length(prompt)+1;
                            prompt=horzcat(prompt,{'ColorBar Font Size'});
                            def=horzcat(def,{num2str(ExportSettings.ColorBarExportFontSize)});
                        end
                        answer = inputdlg(prompt,dlg_title,num_lines,def);
                        ExportSettings.ExportSize(1)=   str2num(answer{1});
                        ExportSettings.ExportSize(2)=   str2num(answer{2});
                        ExportSettings.ExportPosition(1)=   str2num(answer{3});
                        ExportSettings.ExportPosition(2)=   str2num(answer{4});
                        if ScaleBarOn
                            ExportSettings.ScaleBarExportFontSize=str2num(answer{ScaleBarPos});
                        end
                        if ImageLabelOn
                            ExportSettings.ImageLabelExportFontSize=str2num(answer{ImageLabelPos});
                        end
                        if ColorBarOverlayOn
                            ExportSettings.ColorBarExportFontSize=str2num(answer{ColorBarLabelPos});
                        end
                        clear answer
                        if ExportSettings.ExportSize(1)==0
                            ExportSettings.ExportSize(1)=ExportSettings.ExportSize(2)*ExportSettings.ExportSizeRatio;
                        elseif ExportSettings.ExportSize(2)==0
                            ExportSettings.ExportSize(2)=ExportSettings.ExportSize(1)/ExportSettings.ExportSizeRatio;
                        end
                        set(ExportFig,'units','Pixels','position',[ExportSettings.ExportPosition,ExportSettings.ExportSize]);
                        ExportGeneration([],ExportFig,[],[],1,0);
                        SizingExportChoice = questdlg({'Good Export Size?';'NOTE: if any settings were changed RESET will rescale to optimal'},'Good Export Size?','Good','Adjust','Reset','Good');
                        switch SizingExportChoice
                            case 'Adjust'
                                SizingExport=1;
                            case 'Good'
                                SizingExport=0;
                            case 'Reset'
                                SizingExport=1;
                                if ZoomOn
                                    ExportSettings.ExportSize=[ ZoomDataRegion_Props.BoundingBox(3)*ExportSettings.NumColumns*ExportSettings.ScaleFactor,...
                                                                ZoomDataRegion_Props.BoundingBox(4)*ExportSettings.NumRows*ExportSettings.ScaleFactor];
                                else
                                    ExportSettings.ExportSize=[ ImageWidth*ExportSettings.NumColumns*ExportSettings.ScaleFactor,...
                                                                ImageHeight*ExportSettings.NumRows*ExportSettings.ScaleFactor];
                                end
                                ExportSettings.ExportPosition=[0,0];
                                if ExportSettings.ExportSize(2)>ScreenSize(4)-100
                                    ExportScalarModifier=(ScreenSize(4)-100)/ExportSettings.ExportSize(2);
                                    warning(['Adjusting Vertical ExportSize by ',num2str(ExportScalarModifier),' to fit Monitor!'])
                                    ExportSettings.ExportSize=round(ExportSettings.ExportSize*ExportScalarModifier);
                                end
                                if ExportSettings.ExportSize(1)>ScreenSize(3)
                                    ExportScalarModifier=ScreenSize(3)/ExportSettings.ExportSize(1);
                                    warning(['Adjusting Horizontal ExportSize by ',num2str(ExportScalarModifier),' to fit Monitor!'])
                                    ExportSettings.ExportSize=round(ExportSettings.ExportSize*ExportScalarModifier);
                                end
                                ExportSettings.ExportSizeRatio=ExportSettings.ExportSize(1)/ExportSettings.ExportSize(2);
                        end
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    GoodPathName=0;
                    while ~GoodPathName
                        if ExportSettings.ExportMode==1
                            ExportSettings.ImageExportDir=ExportSettings.ImageExportName;
                            prompt = {'ImageExportDir','ImageExportName'};
                            dlg_title = 'Export Properties';
                            num_lines = 1;
                            def = {ExportSettings.ImageExportDir,ExportSettings.ImageExportName};
                            answer = inputdlg(prompt,dlg_title,num_lines,def);
                            ExportSettings.ImageExportDir=                  answer{1};
                            ExportSettings.ImageExportName=                  answer{2};
                            clear answer;
                            if ~exist([ScratchDir,dc,ExportSettings.ImageExportDir])
                                mkdir([ScratchDir,dc,ExportSettings.ImageExportDir])
                            end
                            if length([ScratchDir,dc,ExportSettings.ImageExportDir,dc,ExportSettings.ImageExportName,'.eps'])>260&&strcmp(OS,'PCWIN64')
                                warning('Path+FileName too long for Windows file system please adjust name...')
                                GoodPathName=0;
                            else
                                GoodPathName=1;
                            end


                        elseif ExportSettings.ExportMode==2
                            prompt = {'MovieName','MovieSpeed (FPS)','MovieQuality (1-100)','ScaleFactor','MovieRepeats','MovieFrames'};
                            dlg_title = 'Movie Properties';
                            num_lines = 1;
                            def = {ExportSettings.MovieName,num2str(ExportSettings.MovieSpeed),num2str(ExportSettings.MovieQuality),...
                                num2str(ExportSettings.ScaleFactor),num2str(ExportSettings.MovieRepeats),num2str(ExportSettings.MovieFrames)};
                            answer = inputdlg(prompt,dlg_title,num_lines,def);
                            ExportSettings.MovieName=                  answer{1};
                            ExportSettings.MovieSpeed=         str2num(answer{2});
                            ExportSettings.MovieQuality=       str2num(answer{3});
                            ExportSettings.ScaleFactor=        str2num(answer{4});
                            ExportSettings.MovieRepeats=       str2num(answer{5});
                            ExportSettings.MovieFrames=        str2num(answer{6});
                            clear answer;
                            if ~exist([ScratchDir])
                                mkdir([ScratchDir])
                            end
                            if length([ScratchDir,dc,ExportSettings.MovieName,'.avi'])>260&&strcmp(OS,'PCWIN64')
                                warning('Path+FileName length too long for Windows file system please adjust name...')
                                GoodPathName=0;
                            else
                                GoodPathName=1;
                            end
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                            if exist([ExportDir,dc,ExportSettings.MovieName,ExportSettings.ExportFormatOptions{ExportSettings.ExportFormats}])
                                warning([ExportSettings.MovieName,ExportSettings.ExportFormatOptions{ExportSettings.ExportFormats},' already exists!'])
                                prompt = {[ExportSettings.MovieName,' Exists Rename?']};
                                dlg_title = 'Movie Name';
                                num_lines = 1;
                                def = {ExportSettings.MovieName};
                                answer = inputdlg(prompt,dlg_title,num_lines,def);
                                ExportSettings.MovieName=                  answer{1};
                                clear answer
                            end
                        end                    
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    ExportSetupChoice = questdlg({'Good Export Setup?'},'Good Export Setup?','Good','Adjust','Cancel Export','Good');
                    switch ExportSetupChoice
                        case 'Adjust'
                            ExportSetup=1;
                            StartExport=0;
                        case 'Good'
                            ExportSetup=0;
                            StartExport=1;
                        case 'Cancel Export'
                            ExportSetup=0;
                            StartExport=0;
                            switch ExportSettings.ExportMode
                                case 1
                                    if exist([ScratchDir,dc,ExportSettings.ImageExportName])
                                        warning(['Deleting: ',ExportSettings.ImageExportName]);
                                        recyclestate = recycle;
                                        switch recyclestate
                                            case 'off'
                                                recycle('on');
                                                rmdir([ScratchDir,dc,ExportSettings.ImageExportName],'s');
                                                recycle('off');
                                            case 'on'
                                                rmdir([ScratchDir,dc,ExportSettings.ImageExportName],'s');
                                        end
                                    end
                            end
                    end
                    if exist('ExportFig')
                        try
                            close(ExportFig)
                        catch

                        end
                    end
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                if StartExport
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    if exist('ExportFig')
                        try
                            close(ExportFig)
                        catch

                        end
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    if ExportSettings.ExportMode==1
                        MakeAbortFig=0;
                    elseif ExportSettings.ExportMode==2
                        if ~exist('AbortFig')
                            MakeAbortFig=1;
                        else
                            if ~isvalid(AbortFig)
                                MakeAbortFig=1;
                            end
                        end
                    end
                    if MakeAbortFig
                        AbortFig = figure('name',[ExportSettings.MovieName]);
                        set(gcf,'Units','normalized','Position',[0.8 0.8 0.2 0.1]);
                        AbortText = uicontrol('Style','text',...
                            'units','normalized',...
                            'Fontsize',12,...
                            'Position',[0.01 0.8 0.98 0.2],...
                            'String',[ExportSettings.MovieName],'fontsize',8);
                        AbortButtonHandle = uicontrol('Units','Normalized','Position', [0.05 0.05 0.9 0.75],'style','push',...
                            'string',['Abort ',ExportSettings.MovieName,' Movie'],'callback','set(gcbo,''userdata'',1,''string'',''Aborting!!'')', ...
                            'userdata',0);
                        AbortMovie=0;
                    else
                        AbortMovie=0;
                        AbortButtonHandle=[];
                        AbortFig=[];
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    switch ExportSettings.ExportMode
                        case 1
                            mov=[];
                            ExportFig=figure('name',ExportSettings.ImageExportName);
                        case 2
                            fprintf(['Exporting ',ExportSettings.MovieName,'...\n'])
                            mov = VideoWriter([ScratchDir,dc,ExportSettings.MovieName,ExportSettings.ExportFormatOptions{ExportSettings.ExportFormats}],'Motion JPEG AVI');
                            mov.FrameRate = ExportSettings.MovieSpeed;  % Default 30
                            mov.Quality = ExportSettings.MovieQuality;    % Default 75
                            open(mov);
                            ExportFig=figure('name',ExportSettings.MovieName);
                    end
                    set(ExportFig,'units','Pixels','position',[ExportSettings.ExportPosition,ExportSettings.ExportSize]);
                    set(ExportFig, 'color', 'white');
                    %set(ExportFig,'defaulttextinterpreter','none')
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    ExportGeneration(mov,ExportFig,AbortButtonHandle,AbortFig,0,AbortMovie);
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    if ExportSettings.ExportMode==2
                        close(mov);
                        try
                            close(AbortFig)
                        catch

                        end
                    end
                    close(ExportFig)
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    if ExportSettings.ExportMode==2
                        if ~AbortMovie&&ExportSettings.MovieRepeats>1
                            warning(['Adding Repeats for ',ExportSettings.MovieName])
                            [TempArray,~,~]=ImportMovie([ScratchDir,dc,ExportSettings.MovieName,ExportSettings.ExportFormatOptions{ExportSettings.ExportFormats}]);
                            open(mov);
                            f = waitbar(0,[ExportSettings.MovieName,' Adding Repeats...']); 
                            f.Children.Title.Interpreter = 'none';
                            for r=1:ExportSettings.MovieRepeats
                                for i=1:size(TempArray,4)
                                    waitbar(r/ExportSettings.MovieRepeats,f,[ExportSettings.MovieName,' Adding Repeats...']);
                                    writeVideo(mov,TempArray(:,:,:,i));
                                end
                            end
                            close(mov);
                            waitbar(1,f,['Finished!']);
                            close(f)
                            clear TempArray Temp_AVI_Info TempFPS
                        end
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    switch ExportSettings.ExportMode
                        case 1
                            if Save2Scratch
                                CopyDelete=1;
                                fprintf(['Copying ',ExportSettings.ImageExportName,' To Final ExportDir...'])
                                if ~exist([ExportDir,dc,ExportSettings.ImageExportName])
                                    mkdir([ExportDir,dc,ExportSettings.ImageExportName])
                                end
                                [CopyStatus,CopyMessage]=copyfile([ScratchDir,dc,ExportSettings.ImageExportName],[ExportDir,dc,ExportSettings.ImageExportName]);
                                if CopyStatus
                                    fprintf('Copy successful!\n')
                                    warning('Deleting ScratchDir Version')
                                    recyclestate = recycle;
                                    switch recyclestate
                                        case 'off'
                                            recycle('on');
                                            rmdir([ScratchDir,dc,ExportSettings.ImageExportName],'s');
                                            recycle('off');
                                        case 'on'
                                            rmdir([ScratchDir,dc,ExportSettings.ImageExportName],'s');
                                    end
                                else
                                    warning(CopyMessage)
                                end
                            end
                        case 2
                            if Save2Scratch
                                CopyDelete=1;
                                if AbortMovie
                                    CopyDeleteChoice = questdlg({ExportSettings.MovieName;'was aborted before finishing!';'Copy To Export Dir and Delete from Scratch Dir?'},'Copy 2 ExportDir?','Copy','Skip','Copy');
                                    switch CopyDeleteChoice
                                        case 'Copy'
                                            CopyDelete=1;
                                        case 'Skip'
                                            CopyDelete=0;
                                    end
                                end
                                if CopyDelete
                                    fprintf(['Copying ',ExportSettings.MovieName,' To Final ExportDir...'])
                                    [CopyStatus,CopyMessage]=copyfile([ScratchDir,dc,ExportSettings.MovieName,ExportSettings.ExportFormatOptions{ExportSettings.ExportFormats}],ExportDir);
                                    if CopyStatus
                                        fprintf('Copy successful!\n')
                                        warning('Deleting ScratchDir Version')
                                        recyclestate = recycle;
                                        switch recyclestate
                                            case 'off'
                                                recycle('on');
                                                delete([ScratchDir,dc,ExportSettings.MovieName,ExportSettings.ExportFormatOptions{ExportSettings.ExportFormats}]);
                                                recycle('off');
                                            case 'on'
                                                delete([ScratchDir,dc,ExportSettings.MovieName,ExportSettings.ExportFormatOptions{ExportSettings.ExportFormats}]);
                                        end
                                    else
                                        warning(CopyMessage)
                                    end
                                end
                            end
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    TileChannels=TempTileChannels;
                    TileSlices=TempTileSlices;
                    TileFrames=TempTileFrames;
    %             catch
    %                 WarningPopup = questdlg({'Unable to complete Movie Export!'},'Problem Encountered!','OK','OK');
    %             end
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function ExportGeneration(mov,ExportFig,AbortButtonHandle,AbortFig,TestMode,AbortMovie)
            MakeAbortFig=0;
            if isempty(mov)
            else
                if ~exist('AbortFig')
                    MakeAbortFig=1;
                else
    %                 if ~isvalid(AbortFig)
    %                     MakeAbortFig=1;
    %                 end
                end
            end
            if MakeAbortFig
                AbortFig = figure('name',[ExportSettings.MovieName]);
                set(gcf,'Units','normalized','Position',[0.8 0.8 0.2 0.1]);
                AbortText = uicontrol('Style','text',...
                    'units','normalized',...
                    'Fontsize',12,...
                    'Position',[0.01 0.8 0.98 0.2],...
                    'String',[ExportSettings.MovieName],'fontsize',8);
                AbortButtonHandle = uicontrol('Units','Normalized','Position', [0.05 0.05 0.9 0.75],'style','push',...
                    'string',['Abort ',ExportSettings.MovieName,' Movie'],'callback','set(gcbo,''userdata'',1,''string'',''Aborting!!'')', ...
                    'userdata',0);
                AbortMovie=0;
            else
                AbortMovie=0;
            end
            if ScaleBarOn
                if ~ZoomOn
                    TempFontSizes.ScaleBar.FontSize=ScaleBar.FontSize;
                else
                    TempFontSizes.ZoomScaleBar.FontSize=ZoomScaleBar.FontSize;
                end
            end
            if ImageLabelOn
                if ~ZoomOn
                    TempFontSizes.ImageLabel.FontSize=ImageLabel.FontSize;
                else
                    TempFontSizes.ZoomImageLabel.FontSize=ZoomImageLabel.FontSize;
                end
            end
            if ColorBarOverlayOn
                TempFontSizes.ColorBarOverlay.FontSize=ColorBarOverlay.FontSize;
            end
            if ScaleBarOn
                if ~ZoomOn
                    ScaleBar.FontSize=ExportSettings.ScaleBarExportFontSize;
                    if ScaleBar.FontSize<2
                        ScaleBar.FontSize=2;
                    end
                else
                    ZoomScaleBar.FontSize=ExportSettings.ScaleBarExportFontSize;
                    if ZoomScaleBar.FontSize<2
                        ZoomScaleBar.FontSize=2;
                    end
                end
            end
            if ImageLabelOn
                if ~ZoomOn
                    ImageLabel.FontSize=ExportSettings.ImageLabelExportFontSize;
                    if ImageLabel.FontSize<2
                        ImageLabel.FontSize=2;
                    end
                else
                    ZoomImageLabel.FontSize=ExportSettings.ImageLabelExportFontSize;
                    if ZoomImageLabel.FontSize<2
                        ZoomImageLabel.FontSize=2;
                    end
                end
            end
            if ColorBarOverlayOn
                ColorBarOverlay.FontSize=ExportSettings.ColorBarExportFontSize;
                if ColorBarOverlay.FontSize<2
                    ColorBarOverlay.FontSize=2;
                end
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            switch ExportSettings.ExportMode
                case 1
                    if ~TestMode
                        ExportFormats=ExportSettings.ExportFormatOptions;
                    else
                        ExportFormats={'.pdf'};
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    for f=1:length(ExportFormats)
                        if ZoomOn
                            if ~isempty(ZoomScaleBar)
                                TempScaleBarTextOn=ZoomScaleBar.TextOn;
                            else
                                TempScaleBarTextOn=0;
                            end
                            ZoomScaleBar.TextOn=0;
                        else
                            if ~isempty(ScaleBar)
                                TempScaleBarTextOn=ScaleBar.TextOn;
                            else
                                TempScaleBarTextOn=0;
                            end
                            ScaleBar.TextOn=0;
                        end
                        ScaleBarTextOnCount=0;
                        TempColorBarOverlayOn=ColorBarOverlayOn;
                        ColorBarOverlayOn=0;
                        if strcmp(ExportFormats{f},'.eps')
                            ForceGreekCharacter=0;
                        end
                        if ~TestMode
                            fprintf(['Exporting: ',ExportSettings.ImageExportName,'...'])
                        end
                        AddedColorBar=zeros(size(ExportSettings.C_Range));
                        switch ExportSettings.ExportStyle
                            case 1
                                c1=1;
                                c0=ExportSettings.C_Range(c1);
                                z1=1;
                                z0=ExportSettings.Z_Range(z1);
                                t1=1;
                                t0=ExportSettings.T_Range(t1);
                                %clf
                                PanelCount=0;
                                %SubPlotAxis=[];
                                if z0==0&&c0==0
                                    c0=-1;
                                end
                                if t0==0&&c0==0
                                    c0=-2;
                                end
                                PanelCount=PanelCount+1;
                                SubPlotAxis(PanelCount)=axes('units','normalized','position',ExportSettings.PanelAxes(PanelCount).Axis,'visible','off');
                                SubPlotAxisPos(PanelCount).Position=get(SubPlotAxis(PanelCount),'position');
                                %disp(['Panel',num2str(PanelCount),' z0',num2str(z0),'c0',num2str(c0)]);
                                %set(gca,'DefaultTextInterpreter', 'none')
                                if ZoomOn
                                    [TempExport,TempLabel]=GetCurrentPosition(ImagingInfo,ExportSettings,ExportSettings,ExportSettings,ZoomImageLabel,c0,c1,z0,z1,t0,t1);
                                else
                                    [TempExport,TempLabel]=GetCurrentPosition(ImagingInfo,ExportSettings,ExportSettings,ExportSettings,ImageLabel,c0,c1,z0,z1,t0,t1);
                                end
                                %disp(['p',num2str(PanelCount),'Ch',num2str(c0),'Z',num2str(z0)])
                                %disp(['p',num2str(PanelCount),'Ch',num2str(TempExport.Channel),'Z',num2str(TempExport.Slice),'M',num2str(TempExport.MergeChannel),'ZP',num2str(TempExport.Z_Projection)])
                                TempExportImage=FindCurrentImage(TempExport.Channel,TempExport.Frame,TempExport.Slice,StackOrder,...
                                    TempExport.Z_Projection,TempExport.T_Projection,TempExport.MergeChannel,TempExport.OverwriteMerge,...
                                    TempExport.TileChannels,TempExport.TileSlices,TempExport.TileFrames,TempExport.TileSettings);
                                if (~RGB_Stack&&c0>0)&&~TempExportImage.RGBOn
                                    [TempExportImage.CurrentImage]=Stack_Viewer_Adjust_Contrast_and_Color(TempExportImage.CurrentImage,...
                                        Channel_Info(c0).ColorMap,...
                                        Channel_Info(c0).ContrastLow,...
                                        Channel_Info(c0).ContrastHigh,...
                                        Channel_Info(c0).ValueAdjust,...
                                        Channel_Info(c0).ColorScalar);
                                    if DataRegionMaskOn
                                        TempExportImage.CurrentImage=AddDataRegionMask(TempExportImage.CurrentImage,Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,TempExportImage.RGBOn);
                                    end                                    
                                end
                                if ~TestMode
                                    Image2Export=double(TempExportImage.CurrentImage);
                                    if ZoomOn
                                        Image2Export=imcrop(Image2Export,ZoomDataRegion_Props.BoundingBox);
                                        NameAddition=' Zoom';
                                    else
                                        NameAddition=[];
                                    end
                                    imwrite(Image2Export,...
                                        [ScratchDir,dc,ExportSettings.ImageExportDir,dc,ExportSettings.ImageName,NameAddition,...
                                        ' C',num2str(c0),' Z',num2str(z0),' T',num2str(t0),'.tif']);
                                end
                                if TempColorBarOverlayOn&&z0>0&&t0>0&&~AddedColorBar(c1)
                                    ColorBarOverlayOn=2;
                                end
                                if ScaleBarTextOnCount<1
                                    if ZoomOn
                                        ZoomScaleBar.TextOn=1;
                                    else
                                        ScaleBar.TextOn=1;
                                    end
                                end
                                [ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,ExportSettings.ExportMaskAxes,ExportSettings.ExportTileAxes]=...
                                    ImageDisplay(TempExport.Channel,TempExport.Frame,TempExport.Slice,TempExportImage,ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,...
                                    ExportSettings.ExportMaskAxes,ExportSettings.ExportTileAxes,ExportSettings.ExportSize);
                                if TempColorBarOverlayOn&&z0>0&&t0>0&&~AddedColorBar(c1)
                                    ColorBarOverlayOn=0;
                                    AddedColorBar(c1)=1;
                                end
                                if ScaleBarTextOnCount<1
                                    ScaleBarTextOnCount=ScaleBarTextOnCount+1;
                                    if ZoomOn
                                        ZoomScaleBar.TextOn=0;
                                    else
                                        ScaleBar.TextOn=0;
                                    end
                                end
                                set(SubPlotAxis(PanelCount),'visible','on');
                                if ExportSettings.ExportIncludeTrace
                                    PanelCount=PanelCount+1;
                                    SubPlotAxis(PanelCount)=axes('units','normalized','position',ExportSettings.TraceAxis,'visible','off');
                                    SubPlotAxisPos(PanelCount).Position=get(SubPlotAxis(PanelCount),'position');
                                    TraceDisplay([ExportSettings.T_Range(1),ExportSettings.T_Range(length(ExportSettings.T_Range))],ExportSettings.TraceChannel,t0,ExportSettings.TraceSliceSelection.Z_Range,ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,ExportSettings.SplitTraceAdjust);
                                    if ~TraceScaleOn
                                        set(SubPlotAxis(PanelCount),'visible','on');
                                    end
                                end
                                drawnow
                            case 2
                                t1=1;
                                t0=ExportSettings.T_Range(t1);
                                %clf
                                PanelCount=0;
                                %SubPlotAxis=[];
                                for c1=1:length(ExportSettings.C_Range)
                                    c0=ExportSettings.C_Range(c1);
                                    for z1=1:length(ExportSettings.Z_Range)
                                        z0=ExportSettings.Z_Range(z1);
                                        if z0==0&&c0==0
                                            c0=-1;
                                        end
                                        if t0==0&&c0==0
                                            c0=-2;
                                        end
                                        PanelCount=PanelCount+1;
                                        SubPlotAxis(PanelCount)=axes('units','normalized','position',ExportSettings.PanelAxes(PanelCount).Axis,'visible','off');
                                        SubPlotAxisPos(PanelCount).Position=get(SubPlotAxis(PanelCount),'position');
                                        %disp(['Panel',num2str(PanelCount),' z0',num2str(z0),'c0',num2str(c0)]);
                                        %set(gca,'DefaultTextInterpreter', 'none')
                                        if ZoomOn
                                            [TempExport,TempLabel]=GetCurrentPosition(ImagingInfo,ExportSettings,ExportSettings,ExportSettings,ZoomImageLabel,c0,c1,z0,z1,t0,t1);
                                        else
                                            [TempExport,TempLabel]=GetCurrentPosition(ImagingInfo,ExportSettings,ExportSettings,ExportSettings,ImageLabel,c0,c1,z0,z1,t0,t1);
                                        end
                                        %disp(['p',num2str(PanelCount),'Ch',num2str(c0),'Z',num2str(z0)])
                                        %disp(['p',num2str(PanelCount),'Ch',num2str(TempExport.Channel),'Z',num2str(TempExport.Slice),'M',num2str(TempExport.MergeChannel),'ZP',num2str(TempExport.Z_Projection)])
                                        TempExportImage=FindCurrentImage(TempExport.Channel,TempExport.Frame,TempExport.Slice,StackOrder,...
                                            TempExport.Z_Projection,TempExport.T_Projection,TempExport.MergeChannel,TempExport.OverwriteMerge,...
                                            TempExport.TileChannels,TempExport.TileSlices,TempExport.TileFrames,TempExport.TileSettings);
                                        if (~RGB_Stack&&c0>0)&&~TempExportImage.RGBOn
                                            [TempExportImage.CurrentImage]=Stack_Viewer_Adjust_Contrast_and_Color(TempExportImage.CurrentImage,...
                                                Channel_Info(c0).ColorMap,...
                                                Channel_Info(c0).ContrastLow,...
                                                Channel_Info(c0).ContrastHigh,...
                                                Channel_Info(c0).ValueAdjust,...
                                                Channel_Info(c0).ColorScalar);
                                            if DataRegionMaskOn
                                                TempExportImage.CurrentImage=AddDataRegionMask(TempExportImage.CurrentImage,Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,TempExportImage.RGBOn);
                                            end                                    
                                        end
                                        if ~TestMode
                                            Image2Export=double(TempExportImage.CurrentImage);
                                            if ZoomOn
                                                Image2Export=imcrop(Image2Export,ZoomDataRegion_Props.BoundingBox);
                                                NameAddition=' Zoom';
                                            else
                                                NameAddition=[];
                                            end
                                            imwrite(Image2Export,...
                                                [ScratchDir,dc,ExportSettings.ImageExportDir,dc,ExportSettings.ImageName,NameAddition,...
                                                ' C',num2str(c0),' Z',num2str(z0),' T',num2str(t0),'.tif']);
                                        end
                                        if TempColorBarOverlayOn&&z0>0&&t0>0&&~AddedColorBar(c1)
                                            ColorBarOverlayOn=2;
                                        end
                                        if ScaleBarTextOnCount<1
                                            if ZoomOn
                                                ZoomScaleBar.TextOn=1;
                                            else
                                                ScaleBar.TextOn=1;
                                            end
                                        end
                                        [ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,ExportSettings.ExportMaskAxes,ExportSettings.ExportTileAxes]=...
                                            ImageDisplay(TempExport.Channel,TempExport.Frame,TempExport.Slice,TempExportImage,ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,...
                                            ExportSettings.ExportMaskAxes,ExportSettings.ExportTileAxes,ExportSettings.ExportSize);
                                        if TempColorBarOverlayOn&&z0>0&&t0>0&&~AddedColorBar(c1)
                                            ColorBarOverlayOn=0;
                                            AddedColorBar(c1)=1;
                                        end
                                        if ScaleBarTextOnCount<1
                                            ScaleBarTextOnCount=ScaleBarTextOnCount+1;
                                            if ZoomOn
                                                ZoomScaleBar.TextOn=0;
                                            else
                                                ScaleBar.TextOn=0;
                                            end
                                        end
                                        set(SubPlotAxis(PanelCount),'visible','on');
                                    end
                                end
                                if ExportSettings.ExportIncludeTrace
                                    PanelCount=PanelCount+1;
                                    SubPlotAxis(PanelCount)=axes('units','normalized','position',ExportSettings.TraceAxis,'visible','off');
                                    SubPlotAxisPos(PanelCount).Position=get(SubPlotAxis(PanelCount),'position');
                                    TraceDisplay([ExportSettings.T_Range(1),ExportSettings.T_Range(length(ExportSettings.T_Range))],ExportSettings.TraceChannel,t0,ExportSettings.TraceSliceSelection.Z_Range,ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,ExportSettings.SplitTraceAdjust);
                                    if ~TraceScaleOn
                                        set(SubPlotAxis(PanelCount),'visible','on');
                                    end
                                end
                                drawnow
                            case 3
                                t1=1;
                                t0=ExportSettings.T_Range(t1);
                                %clf
                                PanelCount=0;
                                %SubPlotAxis=[];
                                for z1=1:length(ExportSettings.Z_Range)
                                    z0=ExportSettings.Z_Range(z1);
                                    for c1=1:length(ExportSettings.C_Range)
                                        c0=ExportSettings.C_Range(c1);
                                        if z0==0&&c0==0
                                            c0=-1;
                                        end
                                        if t0==0&&c0==0
                                            c0=-2;
                                        end
                                        PanelCount=PanelCount+1;
                                        SubPlotAxis(PanelCount)=axes('units','normalized','position',ExportSettings.PanelAxes(PanelCount).Axis,'visible','off');
                                        SubPlotAxisPos(PanelCount).Position=get(SubPlotAxis(PanelCount),'position');
                                        %disp(['Panel',num2str(PanelCount),' z0',num2str(z0),'c0',num2str(c0)]);
                                        %set(gca,'DefaultTextInterpreter', 'none')
                                        if ZoomOn
                                            [TempExport,TempLabel]=GetCurrentPosition(ImagingInfo,ExportSettings,ExportSettings,ExportSettings,ZoomImageLabel,c0,c1,z0,z1,t0,t1);
                                        else
                                            [TempExport,TempLabel]=GetCurrentPosition(ImagingInfo,ExportSettings,ExportSettings,ExportSettings,ImageLabel,c0,c1,z0,z1,t0,t1);
                                        end
                                        %disp(['p',num2str(PanelCount),'Ch',num2str(c0),'Z',num2str(z0)])
                                        %disp(['p',num2str(PanelCount),'Ch',num2str(TempExport.Channel),'Z',num2str(TempExport.Slice),'M',num2str(TempExport.MergeChannel),'ZP',num2str(TempExport.Z_Projection)])
                                        TempExportImage=FindCurrentImage(TempExport.Channel,TempExport.Frame,TempExport.Slice,StackOrder,...
                                            TempExport.Z_Projection,TempExport.T_Projection,TempExport.MergeChannel,TempExport.OverwriteMerge,...
                                            TempExport.TileChannels,TempExport.TileSlices,TempExport.TileFrames,TempExport.TileSettings);
                                        if (~RGB_Stack&&c0>0)&&~TempExportImage.RGBOn
                                            [TempExportImage.CurrentImage]=Stack_Viewer_Adjust_Contrast_and_Color(TempExportImage.CurrentImage,...
                                                Channel_Info(c0).ColorMap,...
                                                Channel_Info(c0).ContrastLow,...
                                                Channel_Info(c0).ContrastHigh,...
                                                Channel_Info(c0).ValueAdjust,...
                                                Channel_Info(c0).ColorScalar);
                                            if DataRegionMaskOn
                                                TempExportImage.CurrentImage=AddDataRegionMask(TempExportImage.CurrentImage,Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,TempExportImage.RGBOn);
                                            end                                    
                                        end
                                        if ~TestMode
                                            Image2Export=double(TempExportImage.CurrentImage);
                                            if ZoomOn
                                                Image2Export=imcrop(Image2Export,ZoomDataRegion_Props.BoundingBox);
                                                NameAddition=' Zoom';
                                            else
                                                NameAddition=[];
                                            end
                                            imwrite(Image2Export,...
                                                [ScratchDir,dc,ExportSettings.ImageExportDir,dc,ExportSettings.ImageName,NameAddition,...
                                                ' C',num2str(c0),' Z',num2str(z0),' T',num2str(t0),'.tif']);
                                        end
                                        if TempColorBarOverlayOn&&z0>0&&t0>0&&~AddedColorBar(c1)
                                            ColorBarOverlayOn=2;
                                        end
                                        if ScaleBarTextOnCount<1
                                            if ZoomOn
                                                ZoomScaleBar.TextOn=1;
                                            else
                                                ScaleBar.TextOn=1;
                                            end
                                        end
                                        [ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,ExportSettings.ExportMaskAxes,ExportSettings.ExportTileAxes]=...
                                            ImageDisplay(TempExport.Channel,TempExport.Frame,TempExport.Slice,TempExportImage,ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,...
                                            ExportSettings.ExportMaskAxes,ExportSettings.ExportTileAxes,ExportSettings.ExportSize);
                                        if TempColorBarOverlayOn&&z0>0&&t0>0&&~AddedColorBar(c1)
                                            ColorBarOverlayOn=0;
                                            AddedColorBar(c1)=1;
                                        end
                                        if ScaleBarTextOnCount<1
                                            ScaleBarTextOnCount=ScaleBarTextOnCount+1;
                                            if ZoomOn
                                                ZoomScaleBar.TextOn=0;
                                            else
                                                ScaleBar.TextOn=0;
                                            end
                                        end
                                        set(SubPlotAxis(PanelCount),'visible','on');
                                    end
                                end
                                if ExportSettings.ExportIncludeTrace
                                    PanelCount=PanelCount+1;
                                    SubPlotAxis(PanelCount)=axes('units','normalized','position',ExportSettings.TraceAxis,'visible','off');
                                    SubPlotAxisPos(PanelCount).Position=get(SubPlotAxis(PanelCount),'position');
                                    TraceDisplay([ExportSettings.T_Range(1),ExportSettings.T_Range(length(ExportSettings.T_Range))],ExportSettings.TraceChannel,t0,ExportSettings.TraceSliceSelection.Z_Range,ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,ExportSettings.SplitTraceAdjust);
                                    if ~TraceScaleOn
                                        set(SubPlotAxis(PanelCount),'visible','on');
                                    end
                                end
                                drawnow
                            case 4
                                t1=1;
                                t0=ExportSettings.T_Range(t1);
                                z1=1;
                                z0=ExportSettings.Z_Range(z1);
                                %clf
                                PanelCount=0;
                                %SubPlotAxis=[];
                                for c1=1:length(ExportSettings.C_Range)
                                    c0=ExportSettings.C_Range(c1);
                                    if z0==0&&c0==0
                                        c0=-1;
                                    end
                                    if t0==0&&c0==0
                                        c0=-2;
                                    end
                                    PanelCount=PanelCount+1;
                                    SubPlotAxis(PanelCount)=axes('units','normalized','position',ExportSettings.PanelAxes(PanelCount).Axis,'visible','off');
                                    SubPlotAxisPos(PanelCount).Position=get(SubPlotAxis(PanelCount),'position');
                                    %disp(['Panel',num2str(PanelCount),' z0',num2str(z0),'c0',num2str(c0)]);
                                    %set(gca,'DefaultTextInterpreter', 'none')
                                    if ZoomOn
                                        [TempExport,TempLabel]=GetCurrentPosition(ImagingInfo,ExportSettings,ExportSettings,ExportSettings,ZoomImageLabel,c0,c1,z0,z1,t0,t1);
                                    else
                                        [TempExport,TempLabel]=GetCurrentPosition(ImagingInfo,ExportSettings,ExportSettings,ExportSettings,ImageLabel,c0,c1,z0,z1,t0,t1);
                                    end
                                    %disp(['p',num2str(PanelCount),'Ch',num2str(c0),'Z',num2str(z0)])
                                    %disp(['p',num2str(PanelCount),'Ch',num2str(TempExport.Channel),'Z',num2str(TempExport.Slice),'M',num2str(TempExport.MergeChannel),'ZP',num2str(TempExport.Z_Projection)])
                                    TempExportImage=FindCurrentImage(TempExport.Channel,TempExport.Frame,TempExport.Slice,StackOrder,...
                                        TempExport.Z_Projection,TempExport.T_Projection,TempExport.MergeChannel,TempExport.OverwriteMerge,...
                                        TempExport.TileChannels,TempExport.TileSlices,TempExport.TileFrames,TempExport.TileSettings);
                                    if (~RGB_Stack&&c0>0)&&~TempExportImage.RGBOn
                                        [TempExportImage.CurrentImage]=Stack_Viewer_Adjust_Contrast_and_Color(TempExportImage.CurrentImage,...
                                            Channel_Info(c0).ColorMap,...
                                            Channel_Info(c0).ContrastLow,...
                                            Channel_Info(c0).ContrastHigh,...
                                            Channel_Info(c0).ValueAdjust,...
                                            Channel_Info(c0).ColorScalar);
                                        if DataRegionMaskOn
                                            TempExportImage.CurrentImage=AddDataRegionMask(TempExportImage.CurrentImage,Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,TempExportImage.RGBOn);
                                        end                                    
                                    end
                                    if ~TestMode
                                        Image2Export=double(TempExportImage.CurrentImage);
                                        if ZoomOn
                                            Image2Export=imcrop(Image2Export,ZoomDataRegion_Props.BoundingBox);
                                            NameAddition=' Zoom';
                                        else
                                            NameAddition=[];
                                        end
                                        imwrite(Image2Export,...
                                            [ScratchDir,dc,ExportSettings.ImageExportDir,dc,ExportSettings.ImageName,NameAddition,...
                                            ' C',num2str(c0),' Z',num2str(z0),' T',num2str(t0),'.tif']);
                                    end
                                    if TempColorBarOverlayOn&&z0>0&&t0>0&&~AddedColorBar(c1)
                                        ColorBarOverlayOn=2;
                                    end
                                        if ScaleBarTextOnCount<1
                                            if ZoomOn
                                                ZoomScaleBar.TextOn=1;
                                            else
                                                ScaleBar.TextOn=1;
                                            end
                                        end
                                    [ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,ExportSettings.ExportMaskAxes,ExportSettings.ExportTileAxes]=...
                                        ImageDisplay(TempExport.Channel,TempExport.Frame,TempExport.Slice,TempExportImage,ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,...
                                        ExportSettings.ExportMaskAxes,ExportSettings.ExportTileAxes,ExportSettings.ExportSize);
                                    if TempColorBarOverlayOn&&z0>0&&t0>0&&~AddedColorBar(c1)
                                        ColorBarOverlayOn=0;
                                        AddedColorBar(c1)=1;
                                    end
                                    if ScaleBarTextOnCount<1
                                        ScaleBarTextOnCount=ScaleBarTextOnCount+1;
                                        if ZoomOn
                                            ZoomScaleBar.TextOn=0;
                                        else
                                            ScaleBar.TextOn=0;
                                        end
                                    end
                                    set(SubPlotAxis(PanelCount),'visible','on');
                                end
                                if ExportSettings.ExportIncludeTrace
                                    PanelCount=PanelCount+1;
                                    SubPlotAxis(PanelCount)=axes('units','normalized','position',ExportSettings.TraceAxis,'visible','off');
                                    SubPlotAxisPos(PanelCount).Position=get(SubPlotAxis(PanelCount),'position');
                                    TraceDisplay([ExportSettings.T_Range(1),ExportSettings.T_Range(length(ExportSettings.T_Range))],ExportSettings.TraceChannel,t0,ExportSettings.TraceSliceSelection.Z_Range,ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,ExportSettings.SplitTraceAdjust);
                                    if ~TraceScaleOn
                                        set(SubPlotAxis(PanelCount),'visible','on');
                                    end
                                end
                                drawnow
                            case 5
                                t1=1;
                                t0=ExportSettings.T_Range(t1);
                                c1=1;
                                c0=ExportSettings.C_Range(c1);
                                %clf
                                PanelCount=0;
                                %SubPlotAxis=[];
                                for z1=1:length(ExportSettings.Z_Range)
                                    z0=ExportSettings.Z_Range(z1);
                                    if z0==0&&c0==0
                                        c0=-1;
                                    end
                                    if t0==0&&c0==0
                                        c0=-2;
                                    end
                                    PanelCount=PanelCount+1;
                                    SubPlotAxis(PanelCount)=axes('units','normalized','position',ExportSettings.PanelAxes(PanelCount).Axis,'visible','off');
                                    SubPlotAxisPos(PanelCount).Position=get(SubPlotAxis(PanelCount),'position');
                                    %disp(['Panel',num2str(PanelCount),' z0',num2str(z0),'c0',num2str(c0)]);
                                    %set(gca,'DefaultTextInterpreter', 'none')
                                    if ZoomOn
                                        [TempExport,TempLabel]=GetCurrentPosition(ImagingInfo,ExportSettings,ExportSettings,ExportSettings,ZoomImageLabel,c0,c1,z0,z1,t0,t1);
                                    else
                                        [TempExport,TempLabel]=GetCurrentPosition(ImagingInfo,ExportSettings,ExportSettings,ExportSettings,ImageLabel,c0,c1,z0,z1,t0,t1);
                                    end
                                    %disp(['p',num2str(PanelCount),'Ch',num2str(c0),'Z',num2str(z0)])
                                    %disp(['p',num2str(PanelCount),'Ch',num2str(TempExport.Channel),'Z',num2str(TempExport.Slice),'M',num2str(TempExport.MergeChannel),'ZP',num2str(TempExport.Z_Projection)])
                                    TempExportImage=FindCurrentImage(TempExport.Channel,TempExport.Frame,TempExport.Slice,StackOrder,...
                                        TempExport.Z_Projection,TempExport.T_Projection,TempExport.MergeChannel,TempExport.OverwriteMerge,...
                                        TempExport.TileChannels,TempExport.TileSlices,TempExport.TileFrames,TempExport.TileSettings);
                                    if (~RGB_Stack&&c0>0)&&~TempExportImage.RGBOn
                                        [TempExportImage.CurrentImage]=Stack_Viewer_Adjust_Contrast_and_Color(TempExportImage.CurrentImage,...
                                            Channel_Info(c0).ColorMap,...
                                            Channel_Info(c0).ContrastLow,...
                                            Channel_Info(c0).ContrastHigh,...
                                            Channel_Info(c0).ValueAdjust,...
                                            Channel_Info(c0).ColorScalar);
                                        if DataRegionMaskOn
                                            TempExportImage.CurrentImage=AddDataRegionMask(TempExportImage.CurrentImage,Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,TempExportImage.RGBOn);
                                        end                                    
                                    end
                                    if ~TestMode
                                        Image2Export=double(TempExportImage.CurrentImage);
                                        if ZoomOn
                                            Image2Export=imcrop(Image2Export,ZoomDataRegion_Props.BoundingBox);
                                            NameAddition=' Zoom';
                                        else
                                            NameAddition=[];
                                        end
                                        imwrite(Image2Export,...
                                            [ScratchDir,dc,ExportSettings.ImageExportDir,dc,ExportSettings.ImageName,NameAddition,...
                                            ' C',num2str(c0),' Z',num2str(z0),' T',num2str(t0),'.tif']);
                                    end
                                    if TempColorBarOverlayOn&&z0>0&&t0>0&&~AddedColorBar(c1)
                                        ColorBarOverlayOn=2;
                                    end
                                    if ScaleBarTextOnCount<1
                                        if ZoomOn
                                            ZoomScaleBar.TextOn=1;
                                        else
                                            ScaleBar.TextOn=1;
                                        end
                                    end
                                    [ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,ExportSettings.ExportMaskAxes,ExportSettings.ExportTileAxes]=...
                                        ImageDisplay(TempExport.Channel,TempExport.Frame,TempExport.Slice,TempExportImage,ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,...
                                        ExportSettings.ExportMaskAxes,ExportSettings.ExportTileAxes,ExportSettings.ExportSize);
                                    if TempColorBarOverlayOn&&z0>0&&t0>0&&~AddedColorBar(c1)
                                        ColorBarOverlayOn=0;
                                        AddedColorBar(c1)=1;
                                    end
                                    if ScaleBarTextOnCount<1
                                        ScaleBarTextOnCount=ScaleBarTextOnCount+1;
                                        if ZoomOn
                                            ZoomScaleBar.TextOn=0;
                                        else
                                            ScaleBar.TextOn=0;
                                        end
                                    end
                                    set(SubPlotAxis(PanelCount),'visible','on');
                                end
                                if ExportSettings.ExportIncludeTrace
                                    PanelCount=PanelCount+1;
                                    SubPlotAxis(PanelCount)=axes('units','normalized','position',ExportSettings.TraceAxis,'visible','off');
                                    SubPlotAxisPos(PanelCount).Position=get(SubPlotAxis(PanelCount),'position');
                                    TraceDisplay([ExportSettings.T_Range(1),ExportSettings.T_Range(length(ExportSettings.T_Range))],ExportSettings.TraceChannel,t0,ExportSettings.TraceSliceSelection.Z_Range,ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,ExportSettings.SplitTraceAdjust);
                                    if ~TraceScaleOn
                                        set(SubPlotAxis(PanelCount),'visible','on');
                                    end
                                end
                                drawnow
                            case 6
                                c1=1;
                                c0=ExportSettings.C_Range(c1);
                                z1=1;
                                z0=ExportSettings.Z_Range(z1);
                                %clf
                                PanelCount=0;
                                %SubPlotAxis=[];
                                for t1=1:length(ExportSettings.T_Range)
                                    t0=ExportSettings.T_Range(t1);
                                    if z0==0&&c0==0
                                        c0=-1;
                                    end
                                    if t0==0&&c0==0
                                        c0=-2;
                                    end
                                    PanelCount=PanelCount+1;
                                    SubPlotAxis(PanelCount)=axes('units','normalized','position',ExportSettings.PanelAxes(PanelCount).Axis,'visible','off');
                                    SubPlotAxisPos(PanelCount).Position=get(SubPlotAxis(PanelCount),'position');
                                    %disp(['Panel',num2str(PanelCount),' z0',num2str(z0),'c0',num2str(c0)]);
                                    %set(gca,'DefaultTextInterpreter', 'none')
                                    if ZoomOn
                                        [TempExport,TempLabel]=GetCurrentPosition(ImagingInfo,ExportSettings,ExportSettings,ExportSettings,ZoomImageLabel,c0,c1,z0,z1,t0,t1);
                                    else
                                        [TempExport,TempLabel]=GetCurrentPosition(ImagingInfo,ExportSettings,ExportSettings,ExportSettings,ImageLabel,c0,c1,z0,z1,t0,t1);
                                    end
                                    %disp(['p',num2str(PanelCount),'Ch',num2str(c0),'Z',num2str(z0)])
                                    %disp(['p',num2str(PanelCount),'Ch',num2str(TempExport.Channel),'Z',num2str(TempExport.Slice),'M',num2str(TempExport.MergeChannel),'ZP',num2str(TempExport.Z_Projection)])
                                    TempExportImage=FindCurrentImage(TempExport.Channel,TempExport.Frame,TempExport.Slice,StackOrder,...
                                        TempExport.Z_Projection,TempExport.T_Projection,TempExport.MergeChannel,TempExport.OverwriteMerge,...
                                        TempExport.TileChannels,TempExport.TileSlices,TempExport.TileFrames,TempExport.TileSettings);
                                    if (~RGB_Stack&&c0>0)&&~TempExportImage.RGBOn
                                        [TempExportImage.CurrentImage]=Stack_Viewer_Adjust_Contrast_and_Color(TempExportImage.CurrentImage,...
                                            Channel_Info(c0).ColorMap,...
                                            Channel_Info(c0).ContrastLow,...
                                            Channel_Info(c0).ContrastHigh,...
                                            Channel_Info(c0).ValueAdjust,...
                                            Channel_Info(c0).ColorScalar);
                                        if DataRegionMaskOn
                                            TempExportImage.CurrentImage=AddDataRegionMask(TempExportImage.CurrentImage,Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,TempExportImage.RGBOn);
                                        end                                    
                                    end
                                    if ~TestMode
                                        Image2Export=double(TempExportImage.CurrentImage);
                                        if ZoomOn
                                            Image2Export=imcrop(Image2Export,ZoomDataRegion_Props.BoundingBox);
                                            NameAddition=' Zoom';
                                        else
                                            NameAddition=[];
                                        end
                                        imwrite(Image2Export,...
                                            [ScratchDir,dc,ExportSettings.ImageExportDir,dc,ExportSettings.ImageName,NameAddition,...
                                            ' C',num2str(c0),' Z',num2str(z0),' T',num2str(t0),'.tif']);
                                    end
                                    if TempColorBarOverlayOn&&z0>0&&t0>0&&~AddedColorBar(c1)
                                        ColorBarOverlayOn=2;
                                    end
                                    if ScaleBarTextOnCount<1
                                        if ZoomOn
                                            ZoomScaleBar.TextOn=1;
                                        else
                                            ScaleBar.TextOn=1;
                                        end
                                    end
                                    [ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,ExportSettings.ExportMaskAxes,ExportSettings.ExportTileAxes]=...
                                        ImageDisplay(TempExport.Channel,TempExport.Frame,TempExport.Slice,TempExportImage,ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,...
                                        ExportSettings.ExportMaskAxes,ExportSettings.ExportTileAxes,ExportSettings.ExportSize);
                                    if TempColorBarOverlayOn&&z0>0&&t0>0&&~AddedColorBar(c1)
                                        ColorBarOverlayOn=0;
                                        AddedColorBar(c1)=1;
                                    end
                                    if ScaleBarTextOnCount<1
                                        ScaleBarTextOnCount=ScaleBarTextOnCount+1;
                                        if ZoomOn
                                            ZoomScaleBar.TextOn=0;
                                        else
                                            ScaleBar.TextOn=0;
                                        end
                                    end
                                    set(SubPlotAxis(PanelCount),'visible','on');
                                end
                                if ExportSettings.ExportIncludeTrace
                                    PanelCount=PanelCount+1;
                                    SubPlotAxis(PanelCount)=axes('units','normalized','position',ExportSettings.TraceAxis,'visible','off');
                                    SubPlotAxisPos(PanelCount).Position=get(SubPlotAxis(PanelCount),'position');
                                    TraceDisplay([ExportSettings.T_Range(1),ExportSettings.T_Range(length(ExportSettings.T_Range))],ExportSettings.TraceChannel,t0,ExportSettings.TraceSliceSelection.Z_Range,ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,ExportSettings.SplitTraceAdjust);
                                    if ~TraceScaleOn
                                        set(SubPlotAxis(PanelCount),'visible','on');
                                    end
                                end
                                drawnow
                        end
                        figure(ExportFig)
                        if ~TestMode
                            VectorFileExport(ExportSettings,ExportFig,SubPlotAxis,ExportFormats{f})
                            fprintf('Finished!\n')
                        end
                        ColorBarOverlayOn=TempColorBarOverlayOn;
                        ForceGreekCharacter=1;
                        if ZoomOn
                            ZoomScaleBar.TextOn=TempScaleBarTextOn;
                        else
                            ScaleBar.TextOn=TempScaleBarTextOn;
                        end
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    
                    
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                case 2
                    switch ExportSettings.ExportStyle
                        case 1
                            warning('Not ready')
                        case 2
                            t1=1;
                            HoldingAxes=[];
                            while ~AbortMovie&&t1<=length(ExportSettings.T_Range)
                                t0=ExportSettings.T_Range(t1);
                                %clf
                                PanelCount=0;
                                %SubPlotAxis=[];
                                for c1=1:length(ExportSettings.C_Range)
                                    c0=ExportSettings.C_Range(c1);
                                    for z1=1:length(ExportSettings.Z_Range)
                                        z0=ExportSettings.Z_Range(z1);
                                        if z0==0&&c0==0
                                            c0=-1;
                                        end
                                        if t0==0&&c0==0
                                            c0=-2;
                                        end
                                        PanelCount=PanelCount+1;
                                        SubPlotAxis(PanelCount)=axes('units','normalized','position',ExportSettings.PanelAxes(PanelCount).Axis,'visible','off');
                                        SubPlotAxisPos(PanelCount).Position=get(SubPlotAxis(PanelCount),'position');
                                        %disp(['Panel',num2str(PanelCount),' z0',num2str(z0),'c0',num2str(c0)]);
                                        %set(gca,'DefaultTextInterpreter', 'none')
                                        if ZoomOn
                                            [TempExport,TempLabel]=GetCurrentPosition(ImagingInfo,ExportSettings,ExportSettings,ExportSettings,ZoomImageLabel,c0,c1,z0,z1,t0,t1);
                                        else
                                            [TempExport,TempLabel]=GetCurrentPosition(ImagingInfo,ExportSettings,ExportSettings,ExportSettings,ImageLabel,c0,c1,z0,z1,t0,t1);
                                        end
                                        %disp(['p',num2str(PanelCount),'Ch',num2str(c0),'Z',num2str(z0)])
                                        %disp(['p',num2str(PanelCount),'Ch',num2str(TempExport.Channel),'Z',num2str(TempExport.Slice),'M',num2str(TempExport.MergeChannel),'ZP',num2str(TempExport.Z_Projection)])
                                        TempExportImage=FindCurrentImage(TempExport.Channel,TempExport.Frame,TempExport.Slice,StackOrder,...
                                            TempExport.Z_Projection,TempExport.T_Projection,TempExport.MergeChannel,TempExport.OverwriteMerge,...
                                            TempExport.TileChannels,TempExport.TileSlices,TempExport.TileFrames,TempExport.TileSettings);
                                        if (~RGB_Stack&&c0>0)&&~TempExportImage.RGBOn
                                            [TempExportImage.CurrentImage]=Stack_Viewer_Adjust_Contrast_and_Color(TempExportImage.CurrentImage,...
                                                Channel_Info(c0).ColorMap,...
                                                Channel_Info(c0).ContrastLow,...
                                                Channel_Info(c0).ContrastHigh,...
                                                Channel_Info(c0).ValueAdjust,...
                                                Channel_Info(c0).ColorScalar);
                                            if DataRegionMaskOn
                                                TempExportImage.CurrentImage=AddDataRegionMask(TempExportImage.CurrentImage,Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,TempExportImage.RGBOn);
                                            end                                    
                                        end
                                        [ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,ExportSettings.ExportMaskAxes,ExportSettings.ExportTileAxes]=...
                                            ImageDisplay(TempExport.Channel,TempExport.Frame,TempExport.Slice,TempExportImage,ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,...
                                            ExportSettings.ExportMaskAxes,ExportSettings.ExportTileAxes,ExportSettings.ExportSize);
        %                                 if ZoomOn
        %                                     text(ZoomDataRegion_Props.BoundingBox(1)+ExportSettings.ExportLabelPos_X*(ZoomDataRegion_Props.BoundingBox(3)/ImageWidth),...
        %                                         ZoomDataRegion_Props.BoundingBox(2)+ExportSettings.ExportLabelPos_Y*(ZoomDataRegion_Props.BoundingBox(4)/ImageHeight),...
        %                                         TempLabel,...
        %                                         'color',ExportSettings.C_Colors{c1},'fontname','arial','fontsize',ExportSettings.ExportLabelFontSize);
        %                                 else
        %                                     text(ExportSettings.ExportLabelPos_X,ExportSettings.ExportLabelPos_Y,...
        %                                         TempLabel,...
        %                                         'color',ExportSettings.C_Colors{c1},'fontname','arial','fontsize',ExportSettings.ExportLabelFontSize);
        %                                 end
                                        set(SubPlotAxis(PanelCount),'visible','on');
                                    end
                                end
                                if ExportSettings.ExportIncludeTrace
                                    PanelCount=PanelCount+1;
                                    SubPlotAxis(PanelCount)=axes('units','normalized','position',ExportSettings.TraceAxis,'visible','off');
                                    SubPlotAxisPos(PanelCount).Position=get(SubPlotAxis(PanelCount),'position');
                                    TraceDisplay([ExportSettings.T_Range(1),ExportSettings.T_Range(length(ExportSettings.T_Range))],ExportSettings.TraceChannel,t0,ExportSettings.TraceSliceSelection.Z_Range,ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,ExportSettings.SplitTraceAdjust);
                                    if ~TraceScaleOn
                                        set(SubPlotAxis(PanelCount),'visible','on');
                                    end
                                end
                                drawnow
                                for p=1:length(HoldingAxes)
                                    delete(HoldingAxes(p))
                                end
                                HoldingAxes=SubPlotAxis;
                                figure(ExportFig)
                                if ~TestMode
                                    if ~isempty(mov)
                                        OneFrame = getframe(ExportFig);
                                        for ii=1:ExportSettings.MovieFrames
                                            writeVideo(mov,OneFrame);
                                        end
                                        if get(AbortButtonHandle,'userdata')
                                            warning on;warning('Aborting Movies...');
                                            AbortMovie=1;
                                        else
                                            t1=t1+1;
                                        end
                                    end
                                else
                                    AbortMovie=1;
                                end
                            end
                        case 3
                            t1=1;
                            HoldingAxes=[];
                            while ~AbortMovie&&t1<=length(ExportSettings.T_Range)
                                t0=ExportSettings.T_Range(t1);
                                %clf
                                PanelCount=0;
                                %SubPlotAxis=[];
                                for z1=1:length(ExportSettings.Z_Range)
                                    z0=ExportSettings.Z_Range(z1);
                                    for c1=1:length(ExportSettings.C_Range)
                                        c0=ExportSettings.C_Range(c1);
                                        if z0==0&&c0==0
                                            c0=-1;
                                        end
                                        if t0==0&&c0==0
                                            c0=-2;
                                        end
                                        PanelCount=PanelCount+1;
                                        SubPlotAxis(PanelCount)=axes('units','normalized','position',ExportSettings.PanelAxes(PanelCount).Axis,'visible','off');
                                        SubPlotAxisPos(PanelCount).Position=get(SubPlotAxis(PanelCount),'position');
                                        %disp(['Panel',num2str(PanelCount),' z0',num2str(z0),'c0',num2str(c0)]);
                                        %set(gca,'DefaultTextInterpreter', 'none')
                                        if ZoomOn
                                            [TempExport,TempLabel]=GetCurrentPosition(ImagingInfo,ExportSettings,ExportSettings,ExportSettings,ZoomImageLabel,c0,c1,z0,z1,t0,t1);
                                        else
                                            [TempExport,TempLabel]=GetCurrentPosition(ImagingInfo,ExportSettings,ExportSettings,ExportSettings,ImageLabel,c0,c1,z0,z1,t0,t1);
                                        end
                                        %disp(['p',num2str(PanelCount),'Ch',num2str(c0),'Z',num2str(z0)])
                                        %disp(['p',num2str(PanelCount),'Ch',num2str(TempExport.Channel),'Z',num2str(TempExport.Slice),'M',num2str(TempExport.MergeChannel),'ZP',num2str(TempExport.Z_Projection)])
                                        TempExportImage=FindCurrentImage(TempExport.Channel,TempExport.Frame,TempExport.Slice,StackOrder,...
                                            TempExport.Z_Projection,TempExport.T_Projection,TempExport.MergeChannel,TempExport.OverwriteMerge,...
                                            TempExport.TileChannels,TempExport.TileSlices,TempExport.TileFrames,TempExport.TileSettings);
                                        if (~RGB_Stack&&c0>0)&&~TempExportImage.RGBOn
                                            [TempExportImage.CurrentImage]=Stack_Viewer_Adjust_Contrast_and_Color(TempExportImage.CurrentImage,...
                                                Channel_Info(c0).ColorMap,...
                                                Channel_Info(c0).ContrastLow,...
                                                Channel_Info(c0).ContrastHigh,...
                                                Channel_Info(c0).ValueAdjust,...
                                                Channel_Info(c0).ColorScalar);
                                            if DataRegionMaskOn
                                                TempExportImage.CurrentImage=AddDataRegionMask(TempExportImage.CurrentImage,Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,TempExportImage.RGBOn);
                                            end                                    
                                        end
                                        [ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,ExportSettings.ExportMaskAxes,ExportSettings.ExportTileAxes]=...
                                            ImageDisplay(TempExport.Channel,TempExport.Frame,TempExport.Slice,TempExportImage,ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,...
                                            ExportSettings.ExportMaskAxes,ExportSettings.ExportTileAxes,ExportSettings.ExportSize);
        %                                 if ZoomOn
        %                                     text(ZoomDataRegion_Props.BoundingBox(1)+ExportSettings.ExportLabelPos_X*(ZoomDataRegion_Props.BoundingBox(3)/ImageWidth),...
        %                                         ZoomDataRegion_Props.BoundingBox(2)+ExportSettings.ExportLabelPos_Y*(ZoomDataRegion_Props.BoundingBox(4)/ImageHeight),...
        %                                         TempLabel,...
        %                                         'color',ExportSettings.C_Colors{c1},'fontname','arial','fontsize',ExportSettings.ExportLabelFontSize);
        %                                 else
        %                                     text(ExportSettings.ExportLabelPos_X,ExportSettings.ExportLabelPos_Y,...
        %                                         TempLabel,...
        %                                         'color',ExportSettings.C_Colors{c1},'fontname','arial','fontsize',ExportSettings.ExportLabelFontSize);
        %                                 end
                                        set(SubPlotAxis(PanelCount),'visible','on');
                                    end
                                end
                                if ExportSettings.ExportIncludeTrace
                                    PanelCount=PanelCount+1;
                                    SubPlotAxis(PanelCount)=axes('units','normalized','position',ExportSettings.TraceAxis,'visible','off');
                                    SubPlotAxisPos(PanelCount).Position=get(SubPlotAxis(PanelCount),'position');
                                    TraceDisplay([ExportSettings.T_Range(1),ExportSettings.T_Range(length(ExportSettings.T_Range))],ExportSettings.TraceChannel,t0,ExportSettings.TraceSliceSelection.Z_Range,ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,ExportSettings.SplitTraceAdjust);
                                    if ~TraceScaleOn
                                        set(SubPlotAxis(PanelCount),'visible','on');
                                    end
                                end
                                drawnow
                                for p=1:length(HoldingAxes)
                                    delete(HoldingAxes(p))
                                end
                                HoldingAxes=SubPlotAxis;
                                figure(ExportFig)
                                if ~TestMode
                                    if ~isempty(mov)
                                        OneFrame = getframe(ExportFig);
                                        for ii=1:ExportSettings.MovieFrames
                                            writeVideo(mov,OneFrame);
                                        end
                                        if get(AbortButtonHandle,'userdata')
                                            warning on;warning('Aborting Movies...');
                                            AbortMovie=1;
                                        else
                                            t1=t1+1;
                                        end
                                    end
                                else
                                    AbortMovie=1;
                                end
                            end
                        case 4
                            t1=1;
                            HoldingAxes=[];
                            while ~AbortMovie&&t1<=length(ExportSettings.T_Range)
                                t0=ExportSettings.T_Range(t1);
                                z0=Slice;
                                z1=1;
                                %clf
                                PanelCount=0;
                                %SubPlotAxis=[];
                                for c1=1:length(ExportSettings.C_Range)
                                    c0=ExportSettings.C_Range(c1);
                                    if c0==-1
                                        z0=0;
                                    end
                                    PanelCount=PanelCount+1;
                                    SubPlotAxis(PanelCount)=axes('units','normalized','position',ExportSettings.PanelAxes(PanelCount).Axis,'visible','off');
                                    SubPlotAxisPos(PanelCount).Position=get(SubPlotAxis(PanelCount),'position');
                                    %set(gca,'DefaultTextInterpreter', 'none')
                                    if ZoomOn
                                        [TempExport,TempLabel]=GetCurrentPosition(ImagingInfo,ExportSettings,ExportSettings,ExportSettings,ZoomImageLabel,c0,c1,z0,z1,t0,t1);
                                    else
                                        [TempExport,TempLabel]=GetCurrentPosition(ImagingInfo,ExportSettings,ExportSettings,ExportSettings,ImageLabel,c0,c1,z0,z1,t0,t1);
                                    end
                                    TempExportImage=FindCurrentImage(TempExport.Channel,TempExport.Frame,TempExport.Slice,StackOrder,...
                                            TempExport.Z_Projection,TempExport.T_Projection,TempExport.MergeChannel,TempExport.OverwriteMerge,...
                                            TempExport.TileChannels,TempExport.TileSlices,TempExport.TileFrames,TempExport.TileSettings);
                                    if (~RGB_Stack&&c0>0)&&~TempExportImage.RGBOn
                                        [TempExportImage.CurrentImage]=Stack_Viewer_Adjust_Contrast_and_Color(TempExportImage.CurrentImage,...
                                            Channel_Info(c0).ColorMap,...
                                            Channel_Info(c0).ContrastLow,...
                                            Channel_Info(c0).ContrastHigh,...
                                            Channel_Info(c0).ValueAdjust,...
                                            Channel_Info(c0).ColorScalar);
                                        if DataRegionMaskOn
                                            TempExportImage.CurrentImage=AddDataRegionMask(TempExportImage.CurrentImage,Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,TempExportImage.RGBOn);
                                        end                                    
                                    end
                                    [ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,ExportSettings.ExportMaskAxes,ExportSettings.ExportTileAxes]=...
                                        ImageDisplay(TempExport.Channel,TempExport.Frame,TempExport.Slice,TempExportImage,ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,...
                                        ExportSettings.ExportMaskAxes,ExportSettings.ExportTileAxes,ExportSettings.ExportSize);
                                    set(SubPlotAxis(PanelCount),'visible','on');
                                end
                                if ExportSettings.ExportIncludeTrace
                                    PanelCount=PanelCount+1;
                                    SubPlotAxis(PanelCount)=axes('units','normalized','position',ExportSettings.TraceAxis,'visible','off');
                                    SubPlotAxisPos(PanelCount).Position=get(SubPlotAxis(PanelCount),'position');
                                    TraceDisplay([ExportSettings.T_Range(1),ExportSettings.T_Range(length(ExportSettings.T_Range))],ExportSettings.TraceChannel,t0,ExportSettings.TraceSliceSelection.Z_Range,ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,ExportSettings.SplitTraceAdjust);
                                    if ~TraceScaleOn
                                        set(SubPlotAxis(PanelCount),'visible','on');
                                    end
                                end
                                drawnow
                                for p=1:length(HoldingAxes)
                                    delete(HoldingAxes(p))
                                end
                                HoldingAxes=SubPlotAxis;
                                figure(ExportFig)
                                if ~TestMode
                                    if ~isempty(mov)
                                        OneFrame = getframe(ExportFig);
                                        for ii=1:ExportSettings.MovieFrames
                                            writeVideo(mov,OneFrame);
                                        end
                                        if get(AbortButtonHandle,'userdata')
                                            warning on;warning('Aborting Movies...');
                                            AbortMovie=1;
                                        else
                                            t1=t1+1;
                                        end
                                    end
                                else
                                    AbortMovie=1;
                                end
                            end
                        case 5
                            t1=1;
                            HoldingAxes=[];
                            while ~AbortMovie&&t1<=length(ExportSettings.T_Range)
                                t0=ExportSettings.T_Range(t1);
                                if MergeChannel
                                    c0=0;
                                else
                                    c0=Channel;
                                end
                                c1=1;
                                %clf
                                PanelCount=0;
                                %SubPlotAxis=[];
                                for z1=1:length(ExportSettings.Z_Range)
                                    z0=ExportSettings.Z_Range(z1);
                                    if z0==0&&c0==0
                                        c0=-1;
                                    end
                                    if t0==0&&c0==0
                                        c0=-2;
                                    end
                                    PanelCount=PanelCount+1;
                                    SubPlotAxis(PanelCount)=axes('units','normalized','position',ExportSettings.PanelAxes(PanelCount).Axis,'visible','off');
                                    SubPlotAxisPos(PanelCount).Position=get(SubPlotAxis(PanelCount),'position');
                                    %set(gca,'DefaultTextInterpreter', 'none')
                                    if ZoomOn
                                        [TempExport,TempLabel]=GetCurrentPosition(ImagingInfo,ExportSettings,ExportSettings,ExportSettings,ZoomImageLabel,c0,c1,z0,z1,t0,t1);
                                    else
                                        [TempExport,TempLabel]=GetCurrentPosition(ImagingInfo,ExportSettings,ExportSettings,ExportSettings,ImageLabel,c0,c1,z0,z1,t0,t1);
                                    end
                                    TempExportImage=FindCurrentImage(TempExport.Channel,TempExport.Frame,TempExport.Slice,StackOrder,...
                                            TempExport.Z_Projection,TempExport.T_Projection,TempExport.MergeChannel,TempExport.OverwriteMerge,...
                                            TempExport.TileChannels,TempExport.TileSlices,TempExport.TileFrames,TempExport.TileSettings);
                                    if (~RGB_Stack&&c0>0)&&~TempExportImage.RGBOn
                                        [TempExportImage.CurrentImage]=Stack_Viewer_Adjust_Contrast_and_Color(TempExportImage.CurrentImage,...
                                            Channel_Info(c0).ColorMap,...
                                            Channel_Info(c0).ContrastLow,...
                                            Channel_Info(c0).ContrastHigh,...
                                            Channel_Info(c0).ValueAdjust,...
                                            Channel_Info(c0).ColorScalar);
                                        if DataRegionMaskOn
                                            TempExportImage.CurrentImage=AddDataRegionMask(TempExportImage.CurrentImage,Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,TempExportImage.RGBOn);
                                        end                                    
                                    end
                                    [ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,ExportSettings.ExportMaskAxes,ExportSettings.ExportTileAxes]=...
                                        ImageDisplay(TempExport.Channel,TempExport.Frame,TempExport.Slice,TempExportImage,ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,...
                                        ExportSettings.ExportMaskAxes,ExportSettings.ExportTileAxes,ExportSettings.ExportSize);
                                    set(SubPlotAxis(PanelCount),'visible','on');
                                end
                                if ExportSettings.ExportIncludeTrace
                                    PanelCount=PanelCount+1;
                                    SubPlotAxis(PanelCount)=axes('units','normalized','position',ExportSettings.TraceAxis,'visible','off');
                                    SubPlotAxisPos(PanelCount).Position=get(SubPlotAxis(PanelCount),'position');
                                    TraceDisplay([ExportSettings.T_Range(1),ExportSettings.T_Range(length(ExportSettings.T_Range))],ExportSettings.TraceChannel,t0,ExportSettings.TraceSliceSelection.Z_Range,ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,ExportSettings.SplitTraceAdjust);
                                    if ~TraceScaleOn
                                        set(SubPlotAxis(PanelCount),'visible','on');
                                    end
                                end
                                drawnow
                                for p=1:length(HoldingAxes)
                                    delete(HoldingAxes(p))
                                end
                                HoldingAxes=SubPlotAxis;
                                figure(ExportFig)
                                if ~TestMode
                                    if ~isempty(mov)
                                        OneFrame = getframe(ExportFig);
                                        for ii=1:ExportSettings.MovieFrames
                                            writeVideo(mov,OneFrame);
                                        end
                                        if get(AbortButtonHandle,'userdata')
                                            warning on;warning('Aborting Movies...');
                                            AbortMovie=1;
                                        else
                                            t1=t1+1;
                                        end
                                    end
                                else
                                    AbortMovie=1;
                                end
                            end
                        case 6
                            warning('Not ready')
                        case 7
                            z1=1;
                            HoldingAxes=[];
                            while ~AbortMovie&&z1<=length(ExportSettings.Z_Range)
                                z0=ExportSettings.Z_Range(z1);
                                t0=1;
                                t1=1;
                                %clf
                                PanelCount=0;
                                %SubPlotAxis=[];
                                for c1=1:length(ExportSettings.C_Range)
                                    c0=ExportSettings.C_Range(c1);
                                    if c0==-1
                                        z0=0;
                                    end
                                    PanelCount=PanelCount+1;
                                    SubPlotAxis(PanelCount)=axes('units','normalized','position',ExportSettings.PanelAxes(PanelCount).Axis,'visible','off');
                                    SubPlotAxisPos(PanelCount).Position=get(SubPlotAxis(PanelCount),'position');
                                    %set(gca,'DefaultTextInterpreter', 'none')
                                    if ZoomOn
                                        [TempExport,TempLabel]=GetCurrentPosition(ImagingInfo,ExportSettings,ExportSettings,ExportSettings,ZoomImageLabel,c0,c1,z0,z1,t0,t1);
                                    else
                                        [TempExport,TempLabel]=GetCurrentPosition(ImagingInfo,ExportSettings,ExportSettings,ExportSettings,ImageLabel,c0,c1,z0,z1,t0,t1);
                                    end
                                    TempExportImage=FindCurrentImage(TempExport.Channel,TempExport.Frame,TempExport.Slice,StackOrder,...
                                            TempExport.Z_Projection,TempExport.T_Projection,TempExport.MergeChannel,TempExport.OverwriteMerge,...
                                            TempExport.TileChannels,TempExport.TileSlices,TempExport.TileFrames,TempExport.TileSettings);
                                    if (~RGB_Stack&&c0>0)&&~TempExportImage.RGBOn
                                        [TempExportImage.CurrentImage]=Stack_Viewer_Adjust_Contrast_and_Color(TempExportImage.CurrentImage,...
                                            Channel_Info(c0).ColorMap,...
                                            Channel_Info(c0).ContrastLow,...
                                            Channel_Info(c0).ContrastHigh,...
                                            Channel_Info(c0).ValueAdjust,...
                                            Channel_Info(c0).ColorScalar);
                                        if DataRegionMaskOn
                                            TempExportImage.CurrentImage=AddDataRegionMask(TempExportImage.CurrentImage,Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,TempExportImage.RGBOn);
                                        end                                    
                                    end
                                    [ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,ExportSettings.ExportMaskAxes,ExportSettings.ExportTileAxes]=...
                                        ImageDisplay(TempExport.Channel,TempExport.Frame,TempExport.Slice,TempExportImage,ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,...
                                        ExportSettings.ExportMaskAxes,ExportSettings.ExportTileAxes,ExportSettings.ExportSize);
                                    hold on
                                    set(SubPlotAxis(PanelCount),'visible','on');
                                end
                                if ExportSettings.ExportIncludeTrace
                                    PanelCount=PanelCount+1;
                                    SubPlotAxis(PanelCount)=axes('units','normalized','position',ExportSettings.TraceAxis,'visible','off');
                                    SubPlotAxisPos(PanelCount).Position=get(SubPlotAxis(PanelCount),'position');
                                    TraceDisplay([ExportSettings.T_Range(1),ExportSettings.T_Range(length(ExportSettings.T_Range))],ExportSettings.TraceChannel,t0,ExportSettings.TraceSliceSelection.Z_Range,ExportFig,SubPlotAxis(PanelCount),SubPlotAxisPos(PanelCount).Position,ExportSettings.SplitTraceAdjust);
                                    if ~TraceScaleOn
                                        set(SubPlotAxis(PanelCount),'visible','on');
                                    end
                                end
                                drawnow
                                for p=1:length(HoldingAxes)
                                    delete(HoldingAxes(p))
                                end
                                HoldingAxes=SubPlotAxis;
                                figure(ExportFig)
                                if ~TestMode
                                    if ~isempty(mov)
                                        OneFrame = getframe(ExportFig);
                                        for ii=1:ExportSettings.MovieFrames
                                            writeVideo(mov,OneFrame);
                                        end
                                        if get(AbortButtonHandle,'userdata')
                                            warning on;warning('Aborting Movies...');
                                            AbortMovie=1;
                                        else
                                            z1=z1+1;
                                        end
                                    end
                                else
                                    AbortMovie=1;
                                end
                            end
                    end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if ScaleBarOn
                if ~ZoomOn
                    ScaleBar.FontSize=TempFontSizes.ScaleBar.FontSize;
                else
                    ZoomScaleBar.FontSize=TempFontSizes.ZoomScaleBar.FontSize;
                end
            end
            if ImageLabelOn
                if ~ZoomOn
                    ImageLabel.FontSize=TempFontSizes.ImageLabel.FontSize;
                else
                    ZoomImageLabel.FontSize=TempFontSizes.ZoomImageLabel.FontSize;
                end
            end
            if ColorBarOverlayOn
                ColorBarOverlay.FontSize=TempFontSizes.ColorBarOverlay.FontSize;
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function VectorFileExport(ExportSettings,ExportFig,SubPlotAxis,ExportFormat)
            set(ExportFig, 'color', 'none');
            for ax=1:length(SubPlotAxis)
                try
                    axes(SubPlotAxis(ax))
                    set(SubPlotAxis(ax), 'color', 'none');
                catch
                    warning('Missing Axis...')
                end
            end
            if strcmp(ExportFormat,'.eps')
                ExportTag='-eps';
            elseif strcmp(ExportFormat,'.pdf')
                ExportTag='-pdf';
            end
            export_fig( [ScratchDir,dc,ExportSettings.ImageExportDir,dc,ExportSettings.ImageExportName,ExportFormat],ExportTag,'-nocrop','-transparent');     
            set(ExportFig, 'color', 'w');
            for ax=1:length(SubPlotAxis)
                try
                    axes(SubPlotAxis(ax))
                    set(SubPlotAxis(ax), 'color', 'w');
                catch
                    warning('Missing Axis...')
                end
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function [TempArray,AVI_Info,FPS]=ImportMovie(FileName)
            clear depVideoPlayer videoFReader
            warning on all
            warning off verbose
            warning off backtrace
            warning off
            AVI_Info=aviinfo(FileName);
            warning on
            FPS=AVI_Info.FramesPerSecond;
            videoFReader = vision.VideoFileReader(FileName);
            try
                TempArray=zeros(AVI_Info.Height,AVI_Info.Width,3,AVI_Info.NumFrames,'single');
            catch
                warning('Problem initializing data structure, trying alternative...')
                f = waitbar(0,['Initiailizing .avi...']);
                for zzz=1:AVI_Info.NumFrames
                    waitbar(zzz/AVI_Info.NumFrames,f,['Initiailizing .avi...']);
                    TempArray(:,:,:,zzz)=zeros(AVI_Info.Height,AVI_Info.Width,3,'single');
                end
                waitbar(1,f,['Finished!']);
                close(f)
            end
            f = waitbar(0,['Importing .avi...']);
            for i=1:AVI_Info.NumFrames
                waitbar(i/AVI_Info.NumFrames,f,['Importing .avi...']);
                TempArray(:,:,:,i) = step(videoFReader);
            end
            release(videoFReader);
            clear videoFReader
            waitbar(1,f,['Finished!']);
            close(f)
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function ExportTrace(~,~,~)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ExportTraceButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            try
                InitializeDir
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                prompt = {['TraceExportName: ',ExportSettings.TraceExportName]};
                dlg_title = 'Trace Export';
                num_lines = 1;
                def = {ExportSettings.TraceExportName};
                answer = inputdlg(prompt,dlg_title,num_lines,def);
                ExportSettings.TraceExportName=answer{1};
                clear answer
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                if exist([ExportDir,dc,ExportSettings.TraceExportName,'.eps'])||exist([ExportDir,dc,ExportSettings.TraceExportName,'.pdf'])
                    warning([ExportSettings.TraceExportName,'.eps/.pdf already exists!'])
                    prompt = {ExportSettings.TraceExportName,'.eps/.pdf already exists! Rename?'};
                    dlg_title = 'Trace Export';
                    num_lines = 1;
                    def = {ExportSettings.TraceExportName};
                    answer = inputdlg(prompt,dlg_title,num_lines,def);
                    ExportSettings.TraceExportName=answer{1};
                    clear answer
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                TraceExportFormatsChoice = questdlg('Trace Export Format?','Trace Export Format?','PDF','EPS','Both',TraceExportFormatsChoice);
                ExportPDF=0;
                ExportEPS=0;
                if strcmp(TraceExportFormatsChoice,'Both')
                    ExportPDF=1;
                    ExportEPS=1;
                elseif strcmp(TraceExportFormatsChoice,'PDF')
                    ExportPDF=1;
                    ExportEPS=0;
                elseif strcmp(TraceExportFormatsChoice,'EPS')
                    ExportPDF=0;
                    ExportEPS=1;
                end
                ExportJPEG=0;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                TraceExportFig=figure('units','pixels','position',TraceExportFigPosition,'name',[SaveName,' Traces']);
                set(TraceExportFig,'color','w')
                orient(TraceExportFig,'landscape')
                TraceExportAxes=axes('position',TraceExportAxesPosition);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                AdjustExportTrace=1;
                while AdjustExportTrace
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    figure(TraceExportFig)
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TraceExportAxes,TraceExportAxesPosition,SplitTraceAdjust)
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
                    TraceExportStyleChoice = questdlg('Trace Export Format?','Trace Export Format?','Split','Overlay',TraceExportStyleChoice);
                    if strcmp(TraceExportStyleChoice,'Overlay')
                        SplitTraceAdjust=0;
                    elseif strcmp(TraceExportStyleChoice,'Split')
                        prompt = {'Vertical Trace Spacing'};
                        dlg_title = 'Trace Export Vertical Spacing';
                        num_lines = 1;
                        def = {num2str(SplitTraceAdjust)};
                        answer = inputdlg(prompt,dlg_title,num_lines,def);
                        SplitTraceAdjust=str2num(answer{1});
                    end
                    cla(TraceExportAxes)
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TraceExportAxes,TraceExportAxesPosition,SplitTraceAdjust)
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
                    figure(TraceExportFig)
                    Acknowledged = questdlg('Adjust Figure Size and then <ENTER> in command window?','Resize Trace Figure?','Acknowledged','Acknowledged');
                    cont=input('<ENTER> when satisfied with the figure size');
                    TraceExportFigPosition=get(TraceExportFig,'position');
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
                    prompt = {'Export Axis Left Pos (0-1)','Export Axis Bottom Pos (0-1)','Width (0-1)','Height (0-1)','px to cm conversion'};
                    dlg_title = 'TraceExportAxesPosition';
                    num_lines = 1;
                    def = {num2str(TraceExportAxesPosition(1)),...
                        num2str(TraceExportAxesPosition(2)),...
                        num2str(TraceExportAxesPosition(3)),...
                        num2str(TraceExportAxesPosition(4)),...
                        num2str(Printing_px2cm_scalar)};
                    answer = inputdlg(prompt,dlg_title,num_lines,def);
                    TraceExportAxesPosition(1)=str2num(answer{1});
                    TraceExportAxesPosition(2)=str2num(answer{2});
                    TraceExportAxesPosition(3)=str2num(answer{3});
                    TraceExportAxesPosition(4)=str2num(answer{4});
                    Printing_px2cm_scalar=str2num(answer{5});
                    clear answer
                    set(TraceExportAxes,'position',TraceExportAxesPosition);
                    pause(0.1)
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
                    set(TraceExportFig, 'PaperUnits', 'centimeters');
                    set(TraceExportFig, 'PaperSize', [TraceExportFigPosition(3)*Printing_px2cm_scalar TraceExportFigPosition(4)*Printing_px2cm_scalar]);
                    set(TraceExportFig, 'PaperPositionMode', 'manual');
                    set(TraceExportFig, 'PaperPosition', [0 0 TraceExportFigPosition(3)*Printing_px2cm_scalar TraceExportFigPosition(4)*Printing_px2cm_scalar]);
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    figure(TraceExportFig)
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    TraceSetupChoice = questdlg({'Good Trace Setup?'},'Good Trace Setup?','Good','Adjust','Good');
                    switch TraceSetupChoice
                        case 'Adjust'
                            AdjustExportTrace=1;
                        case 'Good'
                            AdjustExportTrace=0;
                    end
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                AnnotatedImageExports(TraceExportFig,ExportSettings.TraceExportName,ExportPDF,ExportEPS,ExportJPEG,ScratchDir,ExportDir,Save2Scratch)
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                close(TraceExportFig);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            catch
                WarningPopup = questdlg({'Unable to complete Trace Export!'},'Problem Encountered!','OK','OK');

            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ExportTraceButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function ExportData(~,~,~)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ExportDataButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            try
                if isempty(ImagingInfo)
                    CollectImagingInfo
                end
                InitializeDir
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                if ~isfield(ExportSettings,'DataExportName')
                    ExportSettings.DataExportName=[SaveName,' ','Data'];
                end
                prompt = {['DataExportName: ',ExportSettings.DataExportName]};
                dlg_title = 'DataExportName';
                num_lines = 1;
                def = {ExportSettings.DataExportName};
                answer = inputdlg(prompt,dlg_title,num_lines,def);
                ExportSettings.DataExportName=answer{1};
                clear answer
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                if exist([ExportDir,dc,ExportSettings.DataExportName,'.mat'])
                    warning([ExportSettings.DataExportName,'.mat already exists!'])
                    prompt = {ExportSettings.DataExportName,'.mat already exists! Rename?'};
                    dlg_title = 'DataExportName';
                    num_lines = 1;
                    def = {ExportSettings.DataExportName};
                    answer = inputdlg(prompt,dlg_title,num_lines,def);
                    ExportSettings.DataExportName=answer{1};
                    clear answer
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                IncludeAllData = questdlg({'Do you want to include all data (ImageArray, DataRegion MergeStack)';'or just settings and analysis in the save file?'},...
                    'Include All Data?','Include All Data','Dont Include','Dont Include');
                fprintf(['Saving: ',ExportSettings.DataExportName,'.mat'])
                if strcmp(IncludeAllData,'Include All Data')
                    save([ScratchDir,dc,ExportSettings.DataExportName,'.mat'],...
                        'ImageArray',...
                        'DataRegion',...
                        'MergeStack',...
                        'ExportSettings',...
                        'DataRegionBorderLine',...
                        'StackOrder',...
                        'Channel_Labels',...
                        'Channel_Colors',...
                        'Channel_Info',...
                        'ImagingInfo',...
                        'SaveName',...
                        'Locations',...
                        'ROIs',...
                        'ProfileInfo',...
                        'EditRecord',...
                        'Tracker_Z_Data',...
                        'Tracker_T_Data',...
                        'Z_ProjectionSettings',...
                        'Z_Projection_Data',...
                        'Z_Projection_Data',...
                        'Z_Projection_Merge_Data',...
                        'T_ProjectionSettings',...
                        'T_Projection_Data',...
                        'T_Projection_Data',...
                        'T_Projection_Merge_Data'...
                        );
                elseif strcmp(IncludeAllData,'Dont Include')
                    save([ScratchDir,dc,ExportSettings.DataExportName,'.mat'],...
                        'ExportSettings',...
                        'DataRegionBorderLine',...
                        'StackOrder',...
                        'Channel_Labels',...
                        'Channel_Colors',...
                        'Channel_Info',...
                        'ImagingInfo',...
                        'SaveName',...
                        'Locations',...
                        'ROIs',...
                        'ProfileInfo',...
                        'EditRecord',...
                        'Tracker_Z_Data',...
                        'Tracker_T_Data',...
                        'Z_ProjectionSettings',...
                        'Z_Projection_Data',...
                        'Z_Projection_Data',...
                        'Z_Projection_Merge_Data',...
                        'T_ProjectionSettings',...
                        'T_Projection_Data',...
                        'T_Projection_Data',...
                        'T_Projection_Merge_Data'...
                        )
                end
                fprintf('Finished!\n')
                if Save2Scratch
                    CopyDelete=1;
                    if CopyDelete
                        fprintf(['Copying ',ExportSettings.DataExportName,'.mat',' To Final ExportDir...'])
                        [CopyStatus,CopyMessage]=copyfile([ScratchDir,dc,ExportSettings.DataExportName,'.mat'],ExportDir);
                        if CopyStatus
                            fprintf('Copy successful!\n')
                            warning('Deleting ScratchDir Version')
                            recyclestate = recycle;
                            switch recyclestate
                                case 'off'
                                    recycle('on');
                                    delete([ScratchDir,dc,ExportSettings.DataExportName,'.mat']);
                                    recycle('off');
                                case 'on'
                                    delete([ScratchDir,dc,ExportSettings.DataExportName,'.mat']);
                            end
                        else
                            warning(CopyMessage)
                        end
                    end
                end
            catch
                WarningPopup = questdlg({'Unable to complete Data Export!'},'Problem Encountered!','OK','OK');
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ExportDataButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function ImportData(~,~,~)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ImportDataButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            try
           
                    load([ScratchDir,dc,ExportSettings.DataImportName,'.mat'],...
                        'ExportSettings',...
                        'DataRegionBorderLine',...
                        'StackOrder',...
                        'Channel_Labels',...
                        'Channel_Colors',...
                        'Channel_Info',...
                        'ImagingInfo',...
                        'SaveName',...
                        'Locations',...
                        'ROIs',...
                        'ProfileInfo',...
                        'EditRecord',...
                        'Tracker_Z_Data',...
                        'Tracker_T_Data',...
                        'Z_ProjectionSettings',...
                        'Z_Projection_Data',...
                        'Z_Projection_Data',...
                        'Z_Projection_Merge_Data',...
                        'T_ProjectionSettings',...
                        'T_Projection_Data',...
                        'T_Projection_Data',...
                        'T_Projection_Merge_Data'...
                        )
            
            catch
                WarningPopup = questdlg({'Unable to complete Data Export!'},'Problem Encountered!','OK','OK');
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(ImportDataButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function AnnotatedImageExports(ExportFig,ExportName,ExportPDF,ExportEPS,ExportJPEG,ScratchDir,ExportDir,Save2Scratch)
            if ExportPDF
                ExportFileSuffix='.pdf';
                try
                    fprintf([ExportName,ExportFileSuffix,'...'])
                    try
                        fprintf('trying <export_fig.m>...')
                        set(ExportFig, 'color', 'none');
                        export_fig( [ScratchDir,dc,ExportName,ExportFileSuffix], '-pdf','-nocrop','-transparent');
                        set(ExportFig, 'color', 'w');
                    catch
                        fprintf('Problem with or Missing <export_fig.m> tring Print...')
                        print(ExportFig,'-dpdf',[ScratchDir,dc,ExportName,ExportFileSuffix]);
                    end
                    fprintf('Finished!\n')
                    if Save2Scratch
                        CopyDelete=1;
                        if CopyDelete
                            fprintf(['Copying ',ExportName,ExportFileSuffix,' To Final ExportDir...'])
                            [CopyStatus,CopyMessage]=copyfile([ScratchDir,dc,ExportName,ExportFileSuffix],ExportDir);
                            if CopyStatus
                                fprintf('Copy successful!\n')
                                warning('Deleting ScratchDir Version')
                                recyclestate = recycle;
                                switch recyclestate
                                    case 'off'
                                        recycle('on');
                                        delete([ScratchDir,dc,ExportName,ExportFileSuffix]);
                                        recycle('off');
                                    case 'on'
                                        delete([ScratchDir,dc,ExportName,ExportFileSuffix]);
                                end
                            else
                                warning(CopyMessage)
                            end
                        end
                    end
                catch
                    warning(['Unable to Save: ',ExportName,ExportFileSuffix,'!'])
                end
            end
            if ExportEPS
                ExportFileSuffix='.eps';
                try
                    fprintf([ExportName,ExportFileSuffix,'...'])
                    try
                        fprintf('trying <export_fig.m>...')
                        set(ExportFig, 'color', 'none');
                        export_fig( [ScratchDir,dc,ExportName,ExportFileSuffix], '-eps','-nocrop','-transparent');
                        set(ExportFig, 'color', 'w');
                    catch
                        fprintf('Problem with or Missing <export_fig.m> tring Print...')
                        print(ExportFig,'-depsc2',[ScratchDir,dc,ExportName,ExportFileSuffix]);
                    end
                    fprintf('Finished!\n')
                    if Save2Scratch
                        CopyDelete=1;
                        if CopyDelete
                            fprintf(['Copying ',ExportName,ExportFileSuffix,' To Final ExportDir...'])
                            [CopyStatus,CopyMessage]=copyfile([ScratchDir,dc,ExportName,ExportFileSuffix],ExportDir);
                            if CopyStatus
                                fprintf('Copy successful!\n')
                                warning('Deleting ScratchDir Version')
                                recyclestate = recycle;
                                switch recyclestate
                                    case 'off'
                                        recycle('on');
                                        delete([ScratchDir,dc,ExportName,ExportFileSuffix]);
                                        recycle('off');
                                    case 'on'
                                        delete([ScratchDir,dc,ExportName,ExportFileSuffix]);
                                end
                            else
                                warning(CopyMessage)
                            end
                        end
                    end
                catch
                    warning(['Unable to Save: ',ExportName,ExportFileSuffix,'!'])
                end
            end
            if ExportJPEG
                ExportFileSuffix='.jpg';
                try
                    fprintf([ExportName,ExportFileSuffix,'...'])
                    try
                        fprintf('trying <export_fig.m>...')
                        export_fig( [ScratchDir,dc,ExportName,ExportFileSuffix], '-jpg','-nocrop','-q101','-native');  
                    catch
                        fprintf('Problem with or Missing <export_fig.m> tring Print...')
                        print(ExportFig,'-djpg',[ScratchDir,dc,ExportName,ExportFileSuffix]);
                    end
                    
                    fprintf('Finished!\n')
                    if Save2Scratch
                        CopyDelete=1;
                        if CopyDelete
                            fprintf(['Copying ',ExportName,ExportFileSuffix,' To Final ExportDir...'])
                            [CopyStatus,CopyMessage]=copyfile([ScratchDir,dc,ExportName,ExportFileSuffix],ExportDir);
                            if CopyStatus
                                fprintf('Copy successful!\n')
                                warning('Deleting ScratchDir Version')
                                recyclestate = recycle;
                                switch recyclestate
                                    case 'off'
                                        recycle('on');
                                        delete([ScratchDir,dc,ExportName,ExportFileSuffix]);
                                        recycle('off');
                                    case 'on'
                                        delete([ScratchDir,dc,ExportName,ExportFileSuffix]);
                                end
                            else
                                warning(CopyMessage)
                            end
                        end
                    end
                catch
                    warning(['Unable to Save: ',ExportName,ExportFileSuffix,'!'])
                end
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function TileChannelsSetup(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            TempTileChannels=get(TileChannelsButton,'value');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(TileChannelsButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            try
                if TempTileChannels
                    %OverallHist=1;
                    %set(OverallHistButton,'value',OverallHist);
                    %TileSettings.C_Range=[];
                    %TileSettings.Z_Range=[];
                    %TileSettings.T_Range=[];
                    if Z_Stack
                        TileSlices=0;
                        set(TileSlicesButton,'value',TileSlices);
                        %TileSettings.Z_Range=[];
                    end
                    if T_Stack
                        TileFrames=0;
                        set(TileFramesButton,'value',TileFrames);
                        %TileSettings.T_Range=[];
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    NewTile=1;
                    if ~isempty(TileSettings.C_Range)
                        ReuseChoice = questdlg('Previous Tile Setup Exists, Do you want to reuse?','Reuse Previous Tile Setup?','Reuse','New','Reuse');
                        if strcmp(ReuseChoice,'Reuse')
                            NewTile=0;
                        elseif strcmp(ReuseChoice,'New')
                            NewTile=1;
                        end
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    if NewTile
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        [TileSettings]=ChannelSelection(TileSettings);
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        if ~isfield(TileSettings,'NumColumns')
                            ResetDefaultTileLayout=1;
                        else
                            if TileSettings.NumColumns*TileSettings.NumRows>length(TileSettings.C_Range)
                                ResetDefaultTileLayout=1;
                            else
                                ResetDefaultTileLayout=0;
                            end
                        end
                        if ResetDefaultTileLayout
                            if length(TileSettings.C_Range)<=4
                                TileSettings.NumColumns = length(TileSettings.C_Range);
                                TileSettings.NumRows    = 1;
                            elseif length(TileSettings.C_Range)<=8
                                TileSettings.NumColumns = ceil(length(TileSettings.C_Range)/2);
                                TileSettings.NumRows    = 2;
                            else
                                TileSettings.NumColumns = ceil(length(TileSettings.C_Range)/3);
                                TileSettings.NumRows    = 3;
                            end
                        end
                        GoodTile=0;
                        while ~GoodTile
                            prompt = {['NumColumns (',num2str(length(TileSettings.C_Range)),' Total)'],...
                                      ['NumRows    (',num2str(length(TileSettings.C_Range)),' Total)']};
                            dlg_title = 'Channel Tile Layout';
                            num_lines = 1;
                            def = {num2str(TileSettings.NumColumns),num2str(TileSettings.NumRows)};
                            answer = inputdlg(prompt,dlg_title,num_lines,def);
                            TileSettings.NumColumns= str2num(answer{1});
                            TileSettings.NumRows=    str2num(answer{2});
                            clear answer
                            if length(TileSettings.C_Range)>TileSettings.NumColumns*TileSettings.NumRows
                                warning('Not Enough Tiles Try again!');
                            else
                                GoodTile=1;
                            end
                        end
                        %TileSettings.TileWidth=ViewerTileImageAxisPosition(3)/max(TileSettings.NumColumns,TileSettings.NumRows);
                        %TileSettings.TileHeight=ViewerTileImageAxisPosition(4)/max(TileSettings.NumColumns,TileSettings.NumRows);
                        TileSettings.TileWidth=ViewerTileImageAxisPosition(3)/TileSettings.NumColumns;
                        TileSettings.TileHeight=ViewerTileImageAxisPosition(4)/TileSettings.NumRows;
                        tile=0;
                        for row=1:TileSettings.NumRows
                            for col=1:TileSettings.NumColumns
                                tile=tile+1;
                                TileSettings.Tiles(tile).Pos=...
                                    [ViewerTileImageAxisPosition(1)+(col-1)*TileSettings.TileWidth,...
                                     ViewerTileImageAxisPosition(2)+ViewerTileImageAxisPosition(4)-TileSettings.TileHeight-(row-1)*TileSettings.TileHeight,...
                                     TileSettings.TileWidth,TileSettings.TileHeight];
                            end
                        end
                    end
                else
                    for i=1:length(TileAxes)
                        %if isvalid(TileAxes{i})
                            %set(TileAxes{i},'visible','off')
                            delete(TileAxes{i})
                        %end
                    end
                    if MaskOn
                        if ~isempty(MaskAxes)
                            if isfield(MaskAxes,'ForegroundAxis')
                                MaskAxes=rmfield(MaskAxes,'ForegroundAxis');
                            end
                            for i=1:length(MaskAxes)
                                %if isvalid(MaskAxes{i})
                                    delete(MaskAxes{i})
                                %end
                            end
                        end
                        MaskAxes=[];
                    end
                    RefreshViewer
                end
                TileChannels=TempTileChannels;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                if ~RGB_Stack
                    if T_Stack
                        TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                    end
                    if LiveHist
                        HistDisplay(HistAxis,HistAxisPosition);
                    end
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %UpdateDisplay
                CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            catch
                TileChannels=0;
                WarningPopup = questdlg({'Unable to complete Channel Tiling!'},'Problem Encountered!','OK','OK');
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(TileChannelsButton, 'Enable', 'on');
            set(TileChannelsButton,'value',TileChannels);
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
        function TileSlicesSetup(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            TempTileSlices=get(TileSlicesButton,'value');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(TileSlicesButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            try
                if TempTileSlices
                    %OverallHist=1;
                    %set(OverallHistButton,'value',OverallHist);
                    %TileSettings.C_Range=[];
                    %TileSettings.Z_Range=[];
                    %TileSettings.T_Range=[];
                    if C_Stack
                        TileChannels=0;
                        set(TileChannelsButton,'value',TileChannels);
                        %TileSettings.C_Range=[];
                    end
                    if T_Stack
                        TileFrames=0;
                        set(TileFramesButton,'value',TileFrames);
                        %TileSettings.T_Range=[];
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    NewTile=1;
                    if ~isempty(TileSettings.Z_Range)
                        ReuseChoice = questdlg('Previous Tile Setup Exists, Do you want to reuse?','Reuse Previous Tile Setup?','Reuse','New','Reuse');
                        if strcmp(ReuseChoice,'Reuse')
                            NewTile=0;
                        elseif strcmp(ReuseChoice,'New')
                            NewTile=1;
                        end
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    if NewTile
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        [TileSettings]=SliceSelection(TileSettings);
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        if ~isfield(TileSettings,'NumColumns')
                            ResetDefaultTileLayout=1;
                        else
                            if TileSettings.NumColumns*TileSettings.NumRows>length(TileSettings.Z_Range)
                                ResetDefaultTileLayout=1;
                            else
                                ResetDefaultTileLayout=0;
                            end
                        end
                        if ResetDefaultTileLayout
                            if length(TileSettings.Z_Range)<=4
                                TileSettings.NumColumns = length(TileSettings.Z_Range);
                                TileSettings.NumRows    = 1;
                            elseif length(TileSettings.Z_Range)<=8
                                TileSettings.NumColumns = ceil(length(TileSettings.Z_Range)/2);
                                TileSettings.NumRows    = 2;
                            else
                                TileSettings.NumColumns = ceil(length(TileSettings.Z_Range)/3);
                                TileSettings.NumRows    = 3;
                            end
                        end
                        GoodTile=0;
                        while ~GoodTile
                            prompt = {['NumColumns (',num2str(length(TileSettings.Z_Range)),' Total)'],...
                                      ['NumRows    (',num2str(length(TileSettings.Z_Range)),' Total)']};
                            dlg_title = 'Slice Tile Layout';
                            num_lines = 1;
                            def = {num2str(TileSettings.NumColumns),num2str(TileSettings.NumRows)};
                            answer = inputdlg(prompt,dlg_title,num_lines,def);
                            TileSettings.NumColumns= str2num(answer{1});
                            TileSettings.NumRows=    str2num(answer{2});
                            if length(TileSettings.Z_Range)>TileSettings.NumColumns*TileSettings.NumRows
                                warning('Not Enough Tiles Try again!');
                            else
                                GoodTile=1;
                            end
                            clear answer
                        end
                        %TileSettings.TileWidth=ViewerTileImageAxisPosition(3)/max(TileSettings.NumColumns,TileSettings.NumRows);
                        %TileSettings.TileHeight=ViewerTileImageAxisPosition(4)/max(TileSettings.NumColumns,TileSettings.NumRows);
                        TileSettings.TileWidth=ViewerTileImageAxisPosition(3)/TileSettings.NumColumns;
                        TileSettings.TileHeight=ViewerTileImageAxisPosition(4)/TileSettings.NumRows;
                        tile=0;
                        for row=1:TileSettings.NumRows
                            for col=1:TileSettings.NumColumns
                                tile=tile+1;
                                TileSettings.Tiles(tile).Pos=...
                                    [ViewerTileImageAxisPosition(1)+(col-1)*TileSettings.TileWidth,...
                                     ViewerTileImageAxisPosition(2)+ViewerTileImageAxisPosition(4)-TileSettings.TileHeight-(row-1)*TileSettings.TileHeight,...
                                     TileSettings.TileWidth,TileSettings.TileHeight];
                            end
                        end
                    end
                else
                    for i=1:length(TileAxes)
                        %if isvalid(TileAxes{i})
                            %set(TileAxes{i},'visible','off')
                            delete(TileAxes{i})
                        %end
                    end
                    if MaskOn
                        if ~isempty(MaskAxes)
                            if isfield(MaskAxes,'ForegroundAxis')
                                MaskAxes=rmfield(MaskAxes,'ForegroundAxis');
                            end
                            for i=1:length(MaskAxes)
                                %if isvalid(MaskAxes{i})
                                    delete(MaskAxes{i})
                                %end
                            end
                        end
                        MaskAxes=[];
                    end
                    RefreshViewer
                end
                TileSlices=TempTileSlices;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                if ~RGB_Stack
                    if T_Stack
                        TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                    end
                    if LiveHist
                        HistDisplay(HistAxis,HistAxisPosition);
                    end
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %UpdateDisplay
                CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            catch
                TileSlices=0;
                WarningPopup = questdlg({'Unable to complete Slice Tiling!'},'Problem Encountered!','OK','OK');
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(TileSlicesButton, 'Enable', 'on');
            set(TileSlicesButton,'value',TileSlices);
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
        function TileFramesSetup(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            TempTileFrames=get(TileFramesButton,'value');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(TileFramesButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            try
                if TempTileFrames
                    OverallHist=1;
                    set(OverallHistButton,'value',OverallHist);
                    %TileSettings.C_Range=[];
                    %TileSettings.Z_Range=[];
                    %TileSettings.T_Range=[];
                    if C_Stack
                        TileChannels=0;
                        set(TileChannelsButton,'value',TileChannels);
                        %TileSettings.C_Range=[];
                    end
                    if Z_Stack
                        TileSlices=0;
                        set(TileSlicesButton,'value',TileSlices);
                        %TileSettings.Z_Range=[];
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    NewTile=1;
                    if ~isempty(TileSettings.T_Range)
                        ReuseChoice = questdlg('Previous Tile Setup Exists, Do you want to reuse?','Reuse Previous Tile Setup?','Reuse','New','Reuse');
                        if strcmp(ReuseChoice,'Reuse')
                            NewTile=0;
                        elseif strcmp(ReuseChoice,'New')
                            NewTile=1;
                        end
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    if NewTile
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        [TileSettings]=FrameSelection(TileSettings);
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        if ~isfield(TileSettings,'NumColumns')
                            ResetDefaultTileLayout=1;
                        else
                            if TileSettings.NumColumns*TileSettings.NumRows>length(TileSettings.T_Range)
                                ResetDefaultTileLayout=1;
                            else
                                ResetDefaultTileLayout=0;
                            end
                        end
                        if ResetDefaultTileLayout
                            if length(TileSettings.T_Range)<=4
                                TileSettings.NumColumns = length(TileSettings.T_Range);
                                TileSettings.NumRows    = 1;
                            elseif length(TileSettings.T_Range)<=8
                                TileSettings.NumColumns = ceil(length(TileSettings.T_Range)/2);
                                TileSettings.NumRows    = 2;
                            else
                                TileSettings.NumColumns = ceil(length(TileSettings.T_Range)/3);
                                TileSettings.NumRows    = 3;
                            end
                        end
                        GoodTile=0;
                        while ~GoodTile
                            prompt = {['NumColumns (',num2str(length(TileSettings.T_Range)),' Total)'],...
                                      ['NumRows    (',num2str(length(TileSettings.T_Range)),' Total)']};
                            dlg_title = 'Frame Tile Layout';
                            num_lines = 1;
                            def = {num2str(TileSettings.NumColumns),num2str(TileSettings.NumRows)};
                            answer = inputdlg(prompt,dlg_title,num_lines,def);
                            TileSettings.NumColumns= str2num(answer{1});
                            TileSettings.NumRows=    str2num(answer{2});
                            if length(TileSettings.T_Range)>TileSettings.NumColumns*TileSettings.NumRows
                                warning('Not Enough Tiles Try again!');
                            else
                                GoodTile=1;
                            end
                            clear answer
                        end
                        %TileSettings.TileWidth=ViewerTileImageAxisPosition(3)/max(TileSettings.NumColumns,TileSettings.NumRows);
                        %TileSettings.TileHeight=ViewerTileImageAxisPosition(4)/max(TileSettings.NumColumns,TileSettings.NumRows);
                        TileSettings.TileWidth=ViewerTileImageAxisPosition(3)/TileSettings.NumColumns;
                        TileSettings.TileHeight=ViewerTileImageAxisPosition(4)/TileSettings.NumRows;
                        tile=0;
                        for row=1:TileSettings.NumRows
                            for col=1:TileSettings.NumColumns
                                tile=tile+1;
                                TileSettings.Tiles(tile).Pos=...
                                    [ViewerTileImageAxisPosition(1)+(col-1)*TileSettings.TileWidth,...
                                     ViewerTileImageAxisPosition(2)+ViewerTileImageAxisPosition(4)-TileSettings.TileHeight-(row-1)*TileSettings.TileHeight,...
                                     TileSettings.TileWidth,TileSettings.TileHeight];
                            end
                        end
                    end
                else
                    for i=1:length(TileAxes)
                        %if isvalid(TileAxes{i})
                            %set(TileAxes{i},'visible','off')
                            delete(TileAxes{i})
                        %end
                    end
                    if MaskOn
                        if ~isempty(MaskAxes)
                            if isfield(MaskAxes,'ForegroundAxis')
                                MaskAxes=rmfield(MaskAxes,'ForegroundAxis');
                            end
                            for i=1:length(MaskAxes)
                                %if isvalid(MaskAxes{i})
                                    delete(MaskAxes{i})
                                %end
                            end
                        end
                        MaskAxes=[];
                    end
                    RefreshViewer
                end
                TileFrames=TempTileFrames;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                if ~RGB_Stack
                    if T_Stack
                        TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                    end
                    if LiveHist
                        HistDisplay(HistAxis,HistAxisPosition);
                    end
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %UpdateDisplay
                CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            catch
                TileFrames=0;
                WarningPopup = questdlg({'Unable to complete Frame Tiling!'},'Problem Encountered!','OK','OK');
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(TileFramesButton, 'Enable', 'on');
            set(TileFramesButton,'value',TileFrames);
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function MergeChannelSetup(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            MergeChannelSelection=get(MergeChannelButton,'value');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(MergeChannelButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            try
                if MergeChannelSelection
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    CurrentChannel=Channel;
                    NewMerge=1;
                    if ~isempty(MergeStack)
                        ReuseMergeChoice = questdlg('Previous Merge exists, Do you want to reuse?','Reuse Previous Merge?','Reuse','New','Reuse');
                        if strcmp(ReuseMergeChoice,'Reuse')
                            NewMerge=0;
                        elseif strcmp(ReuseChoice,'New')
                            NewMerge=1;
                        end
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    if NewMerge
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        if isempty(Channels2Merge)
                            DefaultChannels2Merge=[1:length(Channel_Info)];
                            Channels2Merge=[];
                        else
                            DefaultChannels2Merge=Channels2Merge;
                            Channels2Merge=[];
                        end
                        [Channels2Merge, ~] = listdlg('PromptString','Select Channels to Merge?',...
                            'ListString',Channel_Labels,'SelectionMode','multiple','InitialValue',DefaultChannels2Merge,'ListSize', [400 200]);
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    if NewMerge
                        LiveMergeChoice = questdlg(...
                            {'I can either fully channel merge the data right now';...
                            'Or Live merge each frame as needed';...
                            'Live merge is more flexible but slower'},...
                            'Live Merge?','Live','Full','Live');
                        switch LiveMergeChoice
                            case 'Live'
                                LiveMerge=1;
                            case 'Full'
                                LiveMerge=0;
                        end
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    if NewMerge&&~LiveMerge
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        for c1=1:length(Channels2Merge)
                            Channel=Channels2Merge(c1);
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                            %UpdateDisplay
                            set(ColorMapList,'Value',Channel_Info(Channel).DisplayColorMapIndex);
                            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
                            ColorBarDisplay(ViewerFig,ColorBarAxis,ColorBarAxisPosition);
                            if Z_Projection&&~T_Projection
                                set(LowDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(1)))
                                set(HighDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)))
                                warning off
                                set(Low_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1))
                                set(High_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                                warning on
                            elseif ~Z_Projection&&T_Projection
                                set(LowDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(1)))
                                set(HighDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(2)))
                                warning off
                                set(Low_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1))
                                set(High_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                                warning on
                            elseif Z_Projection&&T_Projection
                                error('Not Currently Possible')
                            else
                                set(LowDisp,'String',num2str(Channel_Info(Channel).Display_Limits(1)))
                                set(HighDisp,'String',num2str(Channel_Info(Channel).Display_Limits(2)))
                                warning off
                                set(Low_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(1))
                                set(High_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                                warning on
                            end
                            if ~RGB_Stack
                                HistDisplay(HistAxis,HistAxisPosition)
                                if T_Stack
                                    TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                                end
                            end
                            set(ViewerFig,'CloseRequestFcn',[]);
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                            set(ColorMapList,'BackgroundColor','m')
                            set(High_sld,'BackgroundColor','m')
                            set(Low_sld,'BackgroundColor','m')
                            PromptText={['Adjust Color'];['AND Contrast for:'];[Channel_Labels{Channel}]};
                            Prompt(PromptText,PromptViewerFigPosition);
                            uiwait(PromptFig)
                            fprintf('\n');
                            SetColorMap;
                            HighLowContrast
                            Z_Projection_ContrastAdjusted=1;
                            T_Projection_ContrastAdjusted=1;
                            set(ColorMapList,'BackgroundColor',[0.94,0.94,0.94])
                            set(High_sld,'BackgroundColor',[0.94,0.94,0.94])
                            set(Low_sld,'BackgroundColor',[0.94,0.94,0.94])
                            set(ViewerFig,'CloseRequestFcn','closereq');
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                            %UpdateDisplay
                            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                            if ~RGB_Stack
                                HistDisplay(HistAxis,HistAxisPosition)
                                if T_Stack
                                    TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                                end
                            end
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        end
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        if ParallelProcessingAvailable
                            if isempty(ParallelProcessing)
                                ParallelChoice = questdlg('Use Parallel Pool for Merging Data?','Use Parallel Pool?','ParPool','Standard','ParPool');
                                if strcmp(ParallelChoice,'ParPool')
                                    StartParPool;
                                    ParallelProcessing=1;
                                else
                                    ParallelProcessing=0;
                                end
                            end
                        else
                            ParallelProcessing=0;
                        end
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        Merge_ContrastAdjusted=1;
                        Merge_Channels
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    end
                    if NewMerge
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        if Z_Projection
                            Merge_Z_Projection
                        end
                        if T_Projection
                            Merge_T_Projection
                        end
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    MergeChannel=1;
                    if T_Stack
                        set(UpdateTrace_ROI_Button,'value',0);
                        set(UpdateTrace_Pixel_Button,'value',0);
                    end
                    LiveHist=0;
                    NormHist=1;
                    %OverallHist=1;
                    set(LiveHistButton,'value',LiveHist);
                    set(NormHistButton,'value',NormHist);
                    set(OverallHistButton,'value',OverallHist);
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    axes(HistAxis)
                    cla(HistAxis,'reset')
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    Channel=CurrentChannel;
                    set(ColorMapList,'Value',Channel_Info(Channel).DisplayColorMapIndex);
                    CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                    %[ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
                    ColorBarDisplay(ViewerFig,ColorBarAxis,ColorBarAxisPosition);
                    if Z_Projection&&~T_Projection
                        set(LowDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(1)))
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)))
                        warning off
                        set(Low_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1))
                        set(High_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                    elseif ~Z_Projection&&T_Projection
                        set(LowDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(1)))
                        set(HighDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(2)))
                        warning off
                        set(Low_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1))
                        set(High_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                    elseif Z_Projection&&T_Projection
                        error('Not Currently Possible')
                    else
                        set(LowDisp,'String',num2str(Channel_Info(Channel).Display_Limits(1)))
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Display_Limits(2)))
                        warning off
                        set(Low_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(1))
                        set(High_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                        warning on
                    end
                    try
                        if ~RGB_Stack
                            HistDisplay(HistAxis,HistAxisPosition)
                            if T_Stack
                                TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                            end
                        end
                    catch
                        
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    %UpdateDisplay
                    CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                    [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                else
                    MergeChannel=0;
                    LiveHist=1;
                    NormHist=1;
                    OverallHist=0;
                    set(LiveHistButton,'value',LiveHist);
                    set(NormHistButton,'value',NormHist);
                    set(OverallHistButton,'value',OverallHist);
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    axes(HistAxis)
                    cla(HistAxis,'reset')
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    set(ColorMapList,'Value',Channel_Info(Channel).DisplayColorMapIndex);
                    CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                    [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
                    ColorBarDisplay(ViewerFig,ColorBarAxis,ColorBarAxisPosition);
                    if Z_Projection&&~T_Projection
                        set(LowDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(1)))
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)))
                        warning off
                        set(Low_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1))
                        set(High_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                    elseif ~Z_Projection&&T_Projection
                        set(LowDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(1)))
                        set(HighDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(2)))
                        warning off
                        set(Low_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1))
                        set(High_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                        warning on
                    elseif Z_Projection&&T_Projection
                        error('Not Currently Possible')
                    else
                        set(LowDisp,'String',num2str(Channel_Info(Channel).Display_Limits(1)))
                        set(HighDisp,'String',num2str(Channel_Info(Channel).Display_Limits(2)))
                        warning off
                        set(Low_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(1))
                        set(High_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                        warning on
                    end
                    if ~RGB_Stack
                        HistDisplay(HistAxis,HistAxisPosition)
                        if T_Stack
                            TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                        end
                    end
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            catch
                WarningPopup = questdlg({'Unable to complete Channel Merge!'},'Problem Encountered!','OK','OK');
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(MergeChannelButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        function Merge_Channels
            if ~LiveMerge
                CurrentChannel=Channel;
                if Merge_ContrastAdjusted
                    f = waitbar(0,'Merging Channels Please wait...');
                    switch StackOrder
                        case 'YXC'
                            MergeStack=zeros(ImageHeight,ImageWidth,3,'single');
                            warning off
                            for c1=1:length(Channels2Merge)
                                Channel=Channels2Merge(c1);
                                f = waitbar((c1-1)/length(Channels2Merge),f,['Merging ',Channel_Labels{Channel},'...']);
                                Temp=ImageArray(:,:,Channel);
                                [TempColor]=Stack_Viewer_Adjust_Contrast_and_Color(Temp,...
                                    Channel_Info(Channel).ColorMap,...
                                    Channel_Info(Channel).ContrastLow,...
                                    Channel_Info(Channel).ContrastHigh,...
                                    Channel_Info(Channel).ValueAdjust,...
                                    Channel_Info(Channel).ColorScalar);
                                MergeStack=MergeStack+TempColor;
                            end
                            warning on
                        case 'YXTC'
                            fprintf('Merging Frames and Channels')
                            count=0;
                            MergeStack=zeros(ImageHeight,ImageWidth,3,Last_T,'single');
                            warning off
                            for c1=1:length(Channels2Merge)
                                Channel=Channels2Merge(c1);
                                for tt=1:Last_T
                                    Temp=squeeze(ImageArray(:,:,tt,Channel));
                                    [TempColor]=Stack_Viewer_Adjust_Contrast_and_Color(Temp,...
                                        Channel_Info(Channel).ColorMap,...
                                        Channel_Info(Channel).ContrastLow,...
                                        Channel_Info(Channel).ContrastHigh,...
                                        Channel_Info(Channel).ValueAdjust,...
                                        Channel_Info(Channel).ColorScalar);
                                    MergeStack(:,:,:,tt)=MergeStack(:,:,:,tt)+single(TempColor(:,:,:,1));
                                    count=count+1;
                                    if any(count==[1:round((length(Channels2Merge)*Last_T)/TextUpdateIntervals):(length(Channels2Merge)*Last_T)])
                                        fprintf('.')
                                        f = waitbar(tt/Last_T,f,['Merging Frames for ',Channel_Labels{Channel},'...']);
                                    end
                                end
                            end
                            fprintf('Finished!\n');
                            warning on
                        case 'YXCT'
                            fprintf('Merging Frames and Channels')
                            count=0;
                            MergeStack=zeros(ImageHeight,ImageWidth,3,Last_T,'single');
                            warning off
                            for c1=1:length(Channels2Merge)
                                Channel=Channels2Merge(c1);
                                for tt=1:Last_T
                                    Temp=squeeze(ImageArray(:,:,Channel,tt));
                                    [TempColor]=Stack_Viewer_Adjust_Contrast_and_Color(Temp,...
                                        Channel_Info(Channel).ColorMap,...
                                        Channel_Info(Channel).ContrastLow,...
                                        Channel_Info(Channel).ContrastHigh,...
                                        Channel_Info(Channel).ValueAdjust,...
                                        Channel_Info(Channel).ColorScalar);
                                        MergeStack(:,:,:,tt)=MergeStack(:,:,:,tt)+single(TempColor(:,:,:,1));
                                    count=count+1;
                                    if any(count==[1:round((length(Channels2Merge)*Last_T)/TextUpdateIntervals):(length(Channels2Merge)*Last_T)])
                                        fprintf('.')
                                        f = waitbar(tt/Last_T,f,['Merging Frames for ',Channel_Labels{Channel},'...']);
                                    end
                                end
                            end
                            fprintf('Finished!\n');
                            warning on
                        case 'YXZC'
                            fprintf('Merging Slices and Channels')
                            count=0;
                            MergeStack=zeros(ImageHeight,ImageWidth,3,Last_Z,'single');
                            warning off
                            for c1=1:length(Channels2Merge)
                                Channel=Channels2Merge(c1);
                                for zz=1:Last_Z
                                    Temp=squeeze(ImageArray(:,:,zz,Channel));
                                    [TempColor]=Stack_Viewer_Adjust_Contrast_and_Color(Temp,...
                                        Channel_Info(Channel).ColorMap,...
                                        Channel_Info(Channel).ContrastLow,...
                                        Channel_Info(Channel).ContrastHigh,...
                                        Channel_Info(Channel).ValueAdjust,...
                                        Channel_Info(Channel).ColorScalar);
                                    MergeStack(:,:,:,zz)=MergeStack(:,:,:,zz)+single(TempColor(:,:,:,1));
                                    count=count+1;
                                    if any(count==[1:round((length(Channels2Merge)*Last_Z)/TextUpdateIntervals):(length(Channels2Merge)*Last_Z)])
                                        fprintf('.')
                                        f = waitbar(zz/Last_Z,f,['Merging Slices for ',Channel_Labels{Channel},'...']);
                                    end
                                end
                            end
                            fprintf('Finished!\n');
                            warning on
                        case 'YXCZ'
                            fprintf('Merging Slices and Channels')
                            MergeStack=zeros(ImageHeight,ImageWidth,3,Last_Z,'single');
                            if ParallelProcessing
                                fprintf('...')
                                warning off
                                tt=1;
                                Merge_Data=[];
                                tic
                                for zz=1:Last_Z
                                    Merge_Data(zz,tt).Stack=squeeze(ImageArray(:,:,:,zz));
                                    Merge_Data(zz,tt).MergeImage=zeros(ImageHeight,ImageWidth,3,'single');
                                end
                                parfor zz=1:Last_Z
                                    for c1=1:length(Channels2Merge)
                                        Channel=Channels2Merge(c1);
                                        [TempColor]=Stack_Viewer_Adjust_Contrast_and_Color(Merge_Data(zz,tt).Stack(:,:,Channel),...
                                            Channel_Info(Channel).ColorMap,...
                                            Channel_Info(Channel).ContrastLow,...
                                            Channel_Info(Channel).ContrastHigh,...
                                            Channel_Info(Channel).ValueAdjust,...
                                            Channel_Info(Channel).ColorScalar);
                                        Merge_Data(zz,tt).MergeImage=Merge_Data(zz,tt).MergeImage+single(TempColor(:,:,:,1));
                                    end
                                end
                                for zz=1:Last_Z
                                    Merge_Data(zz,tt).Stack=[];
                                    MergeStack(:,:,:,zz)=Merge_Data(zz,tt).MergeImage;
                                end
                                toc
                                fprintf('Finished!\n');
                                warning on
                            else
                                count=0;
                                warning off
                                tt=1;
                                tic
                                for zz=1:Last_Z
                                    for c1=1:length(Channels2Merge)
                                        Channel=Channels2Merge(c1);
                                        Temp=squeeze(ImageArray(:,:,Channel,zz));
                                        [TempColor]=Stack_Viewer_Adjust_Contrast_and_Color(Temp,...
                                            Channel_Info(Channel).ColorMap,...
                                            Channel_Info(Channel).ContrastLow,...
                                            Channel_Info(Channel).ContrastHigh,...
                                            Channel_Info(Channel).ValueAdjust,...
                                            Channel_Info(Channel).ColorScalar);
                                        MergeStack(:,:,:,zz)=MergeStack(:,:,:,zz)+single(TempColor(:,:,:,1));
                                        count=count+1;
                                        if any(count==[1:round((length(Channels2Merge)*Last_Z)/TextUpdateIntervals):(length(Channels2Merge)*Last_Z)])
                                            fprintf('.')
                                            f = waitbar(zz/Last_Z,f,['Merging Slices for ',Channel_Labels{Channel},'...']);
                                        end
                                    end
                                end
                                toc
                                fprintf('Finished!\n');
                                warning on
                            end
                        case 'YXZTC'
                            fprintf('Merging Frames Slices and Channels')
                            count=0;
                            MergeStack=zeros(ImageHeight,ImageWidth,3,Last_T,Last_Z,'single');
                            warning off
                            for c1=1:length(Channels2Merge)
                                Channel=Channels2Merge(c1);
                                for tt=1:Last_T
                                    for zz=1:Last_Z
                                        Temp=squeeze(ImageArray(:,:,zz,tt,Channel));
                                        [TempColor]=Stack_Viewer_Adjust_Contrast_and_Color(Temp,...
                                            Channel_Info(Channel).ColorMap,...
                                            Channel_Info(Channel).ContrastLow,...
                                            Channel_Info(Channel).ContrastHigh,...
                                            Channel_Info(Channel).ValueAdjust,...
                                            Channel_Info(Channel).ColorScalar);
                                        MergeStack(:,:,:,tt,zz)=MergeStack(:,:,:,tt,zz)+single(TempColor(:,:,:,1));
                                        count=count+1;
                                        if any(count==[1:round((length(Channels2Merge)*Last_T*Last_Z)/TextUpdateIntervals):(length(Channels2Merge)*Last_T*Last_Z)])
                                            fprintf('.')
                                            f = waitbar(count/(length(Channels2Merge)*Last_T*Last_Z),f,['Merging Slices & Frames for ',Channel_Labels{Channel},'...']);
                                        end
                                    end
                                end
                            end
                            fprintf('Finished!\n');
                            warning on
                        case 'YXTZC'
                            fprintf('Merging Frames Slices and Channels')
                            count=0;
                            MergeStack=zeros(ImageHeight,ImageWidth,3,Last_T,Last_Z,'single');
                            warning off
                            for c1=1:length(Channels2Merge)
                                Channel=Channels2Merge(c1);
                                for tt=1:Last_T
                                    for zz=1:Last_Z
                                        Temp=squeeze(ImageArray(:,:,tt,zz,Channel));
                                        [TempColor]=Stack_Viewer_Adjust_Contrast_and_Color(Temp,...
                                            Channel_Info(Channel).ColorMap,...
                                            Channel_Info(Channel).ContrastLow,...
                                            Channel_Info(Channel).ContrastHigh,...
                                            Channel_Info(Channel).ValueAdjust,...
                                            Channel_Info(Channel).ColorScalar);
                                        MergeStack(:,:,:,tt,zz)=MergeStack(:,:,:,tt,zz)+single(TempColor(:,:,:,1));
                                        count=count+1;
                                        if any(count==[1:round((length(Channels2Merge)*Last_T*Last_Z)/TextUpdateIntervals):(length(Channels2Merge)*Last_T*Last_Z)])
                                            fprintf('.')
                                            f = waitbar(count/(length(Channels2Merge)*Last_T*Last_Z),f,['Merging Slices & Frames for ',Channel_Labels{Channel},'...']);
                                        end
                                    end
                                end
                            end
                            fprintf('Finished!\n');
                            warning on
                    end
                    waitbar(1,f,['Finished!']);
                    close(f)
                end
                Channel=CurrentChannel;
            end
            set(ColorMapList,'Value',Channel_Info(Channel).DisplayColorMapIndex);
            CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
            [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            ColorBarDisplay(ViewerFig,ColorBarAxis,ColorBarAxisPosition);
            if Z_Projection&&~T_Projection
                set(LowDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(1)))
                set(HighDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)))
                warning off
                set(Low_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1))
                set(High_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                warning on
            elseif ~Z_Projection&&T_Projection
                set(LowDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(1)))
                set(HighDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(2)))
                warning off
                set(Low_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1))
                set(High_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                warning on
            elseif Z_Projection&&T_Projection
                error('Not Currently Possible')
            else
                set(LowDisp,'String',num2str(Channel_Info(Channel).Display_Limits(1)))
                set(HighDisp,'String',num2str(Channel_Info(Channel).Display_Limits(2)))
                warning off
                set(Low_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(1))
                set(High_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                warning on
            end
            if ~RGB_Stack
                HistDisplay(HistAxis,HistAxisPosition)
                if T_Stack
                    TraceDisplay([0,Last_T],Channel,Frame,Slice,ViewerFig,TracePlotAxis,TraceAxisPosition,0)
                end
            end
            Merge_ContrastAdjusted=0;
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function Z_ProjectData(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            Z_Projection=get(Z_ProjectionButton,'value');
            set(Z_ProjectionButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            try
                if Z_Projection
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    New_Z_Projection=1;
                    if ~isempty(Z_Projection_Data)
                        ReuseChoice = questdlg('Previous Z_Projection_Data exists, Do you want to reuse?','Reuse Previous Z_Projection_Data?','Reuse','New','Reuse');
                        if strcmp(ReuseChoice,'Reuse')
                            New_Z_Projection=0;
                        elseif strcmp(ReuseChoice,'New')
                            New_Z_Projection=1;
                        end
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    if New_Z_Projection
                        Z_Projection_ContrastAdjusted=1;
                        if ~RGB_Stack
                            if ~isfield(Z_ProjectionSettings,'Z_ProjectionChoice')
                                Z_ProjectionSettings.Z_ProjectionChoice=1;
                            end
                            [Z_ProjectionSettings.Z_ProjectionChoice, checking] = listdlg('PromptString',...
                                {'Z_Projection Type'},'SelectionMode','single','ListString',Z_ProjectionOptions,'ListSize', [200 200],'InitialValue',Z_ProjectionSettings.Z_ProjectionChoice);
                            Z_ProjectionSettings.Z_ProjectionType=Z_ProjectionOptions{Z_ProjectionSettings.Z_ProjectionChoice};
    %                         [Z_ProjectionSettings.Z_ProjectionColorChoice, checking] = listdlg('PromptString',...
    %                             {'Z_Projection Coloring'},'SelectionMode','single','ListString',Z_ProjectionColoringOptions,'ListSize', [200 200],'InitialValue',1);
    %                         Z_ProjectionSettings.Z_ProjectionColoringMode=Z_ProjectionOptions{Z_ProjectionSettings.Z_ProjectionColorChoice};

                            if T_Stack
                                Z_ProjectionSettings.T_Options=[];
                                for tt=1:Last_T
                                    Z_ProjectionSettings.T_Options{tt}=num2str(tt);
                                end
%                                 [Z_ProjectionSettings.T_Range, checking] = listdlg('PromptString',{'Select T Range to Include'},...
%                                     'SelectionMode','multiple','ListString',Z_ProjectionSettings.T_Options,'ListSize', [200 600],'InitialValue',[1:Last_T]);
                                Z_ProjectionSettings.T_Range=[1:Last_T];
                            else
                                Z_ProjectionSettings.T_Range=[1];
                            end
                            if Z_Stack
                                if ~isfield(Z_ProjectionSettings,'Z_Range')
                                    Z_ProjectionSettings.Z_Range=[1:Last_Z];
                                end
                                Z_ProjectionSettings.Z_Options=[];
                                for zz=1:Last_Z
                                    Z_ProjectionSettings.Z_Options{zz}=num2str(zz);
                                end
                                [Z_ProjectionSettings.Z_Range, checking] = listdlg('PromptString',{'Select Z Range to Include'},...
                                    'SelectionMode','multiple','ListString',Z_ProjectionSettings.Z_Options,'ListSize', [200 600],'InitialValue',Z_ProjectionSettings.Z_Range);
                            else
                                Z_ProjectionSettings.Z_Range=[1];
                            end
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                            f = waitbar(0,[Z_ProjectionSettings.Z_ProjectionType,' Z Projection Please wait...']);
                            switch StackOrder
                                case 'YXT'
                                    warning('No Z Data!')
                                    Z_Projection=0;
                                case 'YXZ'
                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                    c=1;
                                    count=0;
                                    fprintf([Z_ProjectionSettings.Z_ProjectionType,' Z Projecting Slices and Frames']);
                                    for t1=1:length(Z_ProjectionSettings.T_Range)
                                        t=Z_ProjectionSettings.T_Range(t1);
                                        Z_Projection_Data(c,t).Stack=[];
                                        for z1=1:length(Z_ProjectionSettings.Z_Range)
                                            z=Z_ProjectionSettings.Z_Range(z1);
                                            %%%%%%%%%%%%%%%%%%
                                            %%%%%%%%%%%%%%%%%%
                                            TempImage=ImageArray(:,:,z);
                                            %%%%%%%%%%%%%%%%%%
                                            %%%%%%%%%%%%%%%%%%
                                            TempImage=squeeze(TempImage);
                                            Z_Projection_Data(c,t).Stack=cat(3,...
                                                Z_Projection_Data(c,t).Stack,TempImage);
                                            count=count+1;
                                            if any(count==[1:round((Last_Z*Last_T)/TextUpdateIntervals):(Last_Z*Last_T)])
                                                fprintf('.')
                                                waitbar(count/(Last_Z*Last_T),f,[Z_ProjectionSettings.Z_ProjectionType,' Z Projection...']);
                                            end
                                        end
                                    end
                                    fprintf('Finished!\n');
                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                case 'YXC'
                                    warning('No Z Data!')
                                    Z_Projection=0;
                                    set(Z_ProjectionButton,'value',Z_Projection);
                                case 'YXZT'
                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                    c=1;
                                    count=0;
                                    fprintf([Z_ProjectionSettings.Z_ProjectionType,' Z Projecting Slices and Frames']);
                                    for t1=1:length(Z_ProjectionSettings.T_Range)
                                        t=Z_ProjectionSettings.T_Range(t1);
                                        Z_Projection_Data(c,t).Stack=[];
                                        for z1=1:length(Z_ProjectionSettings.Z_Range)
                                            z=Z_ProjectionSettings.Z_Range(z1);
                                            %%%%%%%%%%%%%%%%%%
                                            %%%%%%%%%%%%%%%%%%
                                            TempImage=ImageArray(:,:,z,t);
                                            %%%%%%%%%%%%%%%%%%
                                            %%%%%%%%%%%%%%%%%%
                                            TempImage=squeeze(TempImage);
                                            Z_Projection_Data(c,t).Stack=cat(3,...
                                                Z_Projection_Data(c,t).Stack,TempImage);
                                            count=count+1;
                                            if any(count==[1:round((Last_Z*Last_T)/TextUpdateIntervals):(Last_Z*Last_T)])
                                                fprintf('.')
                                                waitbar(count/(Last_Z*Last_T),f,[Z_ProjectionSettings.Z_ProjectionType,' Z Projection...']);
                                            end
                                        end
                                    end
                                    fprintf('Finished!\n');
                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                case 'YXTZ'
                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                    c=1;
                                    count=0;
                                    fprintf([Z_ProjectionSettings.Z_ProjectionType,' Z Projecting Slices and Frames']);
                                    for t1=1:length(Z_ProjectionSettings.T_Range)
                                        t=Z_ProjectionSettings.T_Range(t1);
                                        Z_Projection_Data(c,t).Stack=[];
                                        for z1=1:length(Z_ProjectionSettings.Z_Range)
                                            z=Z_ProjectionSettings.Z_Range(z1);
                                            %%%%%%%%%%%%%%%%%%
                                            %%%%%%%%%%%%%%%%%%
                                            TempImage=ImageArray(:,:,t,z);
                                            %%%%%%%%%%%%%%%%%%
                                            %%%%%%%%%%%%%%%%%%
                                            TempImage=squeeze(TempImage);
                                            Z_Projection_Data(c,t).Stack=cat(3,...
                                                Z_Projection_Data(c,t).Stack,TempImage);
                                            count=count+1;
                                            if any(count==[1:round((Last_Z*Last_T)/TextUpdateIntervals):(Last_Z*Last_T)])
                                                fprintf('.')
                                                waitbar(count/(Last_Z*Last_T),f,[Z_ProjectionSettings.Z_ProjectionType,' Z Projection...']);
                                            end
                                        end
                                    end
                                    fprintf('Finished!\n');
                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                case 'YXTC'
                                    warning('No Z Data!')
                                    Z_Projection=0;
                                    set(Z_ProjectionButton,'value',Z_Projection);
                                case 'YXCT'
                                    warning('No Z Data!')
                                    Z_Projection=0;
                                    set(Z_ProjectionButton,'value',Z_Projection);
                                case 'YXZC'
                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                    for c=1:Last_C
                                        fprintf([Z_ProjectionSettings.Z_ProjectionType,' Z Projecting ',Channel_Labels{c},' and Slices']);
                                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                        count=0;
                                        for t1=1:length(Z_ProjectionSettings.T_Range)
                                            t=Z_ProjectionSettings.T_Range(t1);
                                            Z_Projection_Data(c,t).Stack=[];
                                            for z1=1:length(Z_ProjectionSettings.Z_Range)
                                                z=Z_ProjectionSettings.Z_Range(z1);
                                                %%%%%%%%%%%%%%%%%%
                                                %%%%%%%%%%%%%%%%%%
                                                TempImage=ImageArray(:,:,z,c);
                                                %%%%%%%%%%%%%%%%%%
                                                %%%%%%%%%%%%%%%%%%
                                                TempImage=squeeze(TempImage);
                                                Z_Projection_Data(c,t).Stack=cat(3,...
                                                    Z_Projection_Data(c,t).Stack,TempImage);
                                                count=count+1;
                                                if any(count==[1:round((Last_Z*Last_T)/TextUpdateIntervals):(Last_Z*Last_T)])
                                                    fprintf('.')
                                                    waitbar(count/(Last_Z*Last_T),f,[Z_ProjectionSettings.Z_ProjectionType,' Z Projection ',Channel_Labels{c},'...']);
                                                end
                                            end
                                        end
                                        fprintf('Finished!\n');
                                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                    end
                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                case 'YXCZ'
                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                    Z_ProjectionSettings.Z_Range
                                    for c=1:Last_C
                                        fprintf([Z_ProjectionSettings.Z_ProjectionType,' Z Projecting ',Channel_Labels{c},' and Slices']);
                                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                        count=0;
                                        for t1=1:length(Z_ProjectionSettings.T_Range)
                                            t=Z_ProjectionSettings.T_Range(t1);
                                            Z_Projection_Data(c,t).Stack=[];
                                            for z1=1:length(Z_ProjectionSettings.Z_Range)
                                                z=Z_ProjectionSettings.Z_Range(z1);
                                                %%%%%%%%%%%%%%%%%%
                                                %%%%%%%%%%%%%%%%%%
                                                TempImage=ImageArray(:,:,c,z);
                                                %%%%%%%%%%%%%%%%%%
                                                %%%%%%%%%%%%%%%%%%
                                                TempImage=squeeze(TempImage);
                                                Z_Projection_Data(c,t).Stack=cat(3,...
                                                    Z_Projection_Data(c,t).Stack,TempImage);
                                                count=count+1;
                                                if any(count==[1:round((Last_Z*Last_T)/TextUpdateIntervals):(Last_Z*Last_T)])
                                                    fprintf('.')
                                                    waitbar(count/(Last_Z*Last_T),f,[Z_ProjectionSettings.Z_ProjectionType,' Z Projection ',Channel_Labels{c},'...']);
                                                end
                                            end
                                        end
                                        fprintf('Finished!\n');
                                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                    end
                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                case 'YXZTC'
                                    for c=1:Last_C
                                        fprintf([Z_ProjectionSettings.Z_ProjectionType,' Z Projecting ',Channel_Labels{c},' Slices and Frames']);
                                        count=0;
                                        for t1=1:length(Z_ProjectionSettings.T_Range)
                                            t=Z_ProjectionSettings.T_Range(t1);
                                            Z_Projection_Data(c,t).Stack=[];
                                            for z1=1:length(Z_ProjectionSettings.Z_Range)
                                                z=Z_ProjectionSettings.Z_Range(z1);
                                                %%%%%%%%%%%%%%%%%%
                                                %%%%%%%%%%%%%%%%%%
                                                TempImage=ImageArray(:,:,z,t,c);
                                                %%%%%%%%%%%%%%%%%%
                                                %%%%%%%%%%%%%%%%%%
                                                TempImage=squeeze(TempImage);
                                                Z_Projection_Data(c,t).Stack=cat(3,...
                                                    Z_Projection_Data(c,t).Stack,TempImage);
                                                count=count+1;
                                                if any(count==[1:round((Last_Z*Last_T)/TextUpdateIntervals):(Last_Z*Last_T)])
                                                    fprintf('.')
                                                    waitbar(count/(Last_Z*Last_T),f,[Z_ProjectionSettings.Z_ProjectionType,' Z Projection ',Channel_Labels{c},'...']);
                                                end
                                            end
                                        end
                                        fprintf('Finished!\n');
                                    end
                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                case 'YXTZC'
                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                    for c=1:Last_C
                                        fprintf([Z_ProjectionSettings.Z_ProjectionType,' Z Projecting ',Channel_Labels{c},' Slices and Frames']);
                                        count=0;
                                        for t1=1:length(Z_ProjectionSettings.T_Range)
                                            t=Z_ProjectionSettings.T_Range(t1);
                                            Z_Projection_Data(c,t).Stack=[];
                                            for z1=1:length(Z_ProjectionSettings.Z_Range)
                                                z=Z_ProjectionSettings.Z_Range(z1);
                                                %%%%%%%%%%%%%%%%%%
                                                %%%%%%%%%%%%%%%%%%
                                                TempImage=ImageArray(:,:,t,z,c);
                                                %%%%%%%%%%%%%%%%%%
                                                %%%%%%%%%%%%%%%%%%
                                                TempImage=squeeze(TempImage);
                                                Z_Projection_Data(c,t).Stack=cat(3,...
                                                    Z_Projection_Data(c,t).Stack,TempImage);
                                                count=count+1;
                                                if any(count==[1:round((Last_Z*Last_T)/TextUpdateIntervals):(Last_Z*Last_T)])
                                                    fprintf('.')
                                                    waitbar(count/(Last_Z*Last_T),f,[Z_ProjectionSettings.Z_ProjectionType,' Z Projection ',Channel_Labels{c},'...']);
                                                end
                                            end
                                        end
                                        fprintf('Finished!\n');
                                    end
                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                case 'YX[RGB]T'
                                    Z_Projection=0;
                                    set(Z_ProjectionButton,'value',Z_Projection);
                                case 'YXT[RGB]'
                                    Z_Projection=0;
                                    set(Z_ProjectionButton,'value',Z_Projection);
                            end
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                            if Z_Projection
                                for c=1:size(Z_Projection_Data,1)
                                    for t=1:size(Z_Projection_Data,2)
                                        switch Z_ProjectionSettings.Z_ProjectionType
                                            case 'Max'
                                                Z_Projection_Data(c,t).Proj=...
                                                    max(Z_Projection_Data(c,t).Stack,[],3);
                                            case 'Min'
                                                Z_Projection_Data(c,t).Proj=...
                                                    min(Z_Projection_Data(c,t).Stack,[],3);
                                            case 'Avg'
                                                Z_Projection_Data(c,t).Proj=...
                                                    mean(Z_Projection_Data(c,t).Stack,3);
                                            case 'Sum'
                                                Z_Projection_Data(c,t).Proj=...
                                                    sum(Z_Projection_Data(c,t).Stack,3);
                                        end
                                        Z_Projection_Data(c,t).Stack=[];
                                    end
                                    Channel_Info(c).Z_Projection_Data.ColorMaps.ColorMap=Channel_Info(c).ColorMap;
    %                                 switch Z_ProjectionSettings.Z_ProjectionColoringMode
    %                                     case 'Channel'
    %                                         Channel_Info(c).Z_Projection_Data.ColorMaps.ColorMap=Channel_Info(c).ColorMap;
    %                                     case 'Unique'
    %                                     case 'Graded'
    %                                 end
                                    Channel_Info(c).Z_Projection_Data.Normalized_Display_Limits=Channel_Info(c).Normalized_Display_Limits;
                                    Channel_Info(c).Z_Projection_Data.Display_Limits=Channel_Info(c).Display_Limits;
                                    Channel_Info(c).Z_Projection_Data.ContrastLow=Channel_Info(c).ContrastLow;
                                    Channel_Info(c).Z_Projection_Data.ContrastHigh=Channel_Info(c).ContrastHigh;
                                    Channel_Info(c).Z_Projection_Data.ValueAdjust=Channel_Info(c).ValueAdjust;
                                end
                            end
                            waitbar(1,f,['Finished!']);
                            close(f)
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                            if MergeChannel
                                Merge_Z_Projection
                            end
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        else
                            warning('Unable to project RGB Data!')
                            Z_Projection=0;
                            set(Z_ProjectionButton,'value',Z_Projection);
                        end
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    set(ColorMapList,'Value',Channel_Info(Channel).DisplayColorMapIndex);
                    warning off
                    set(High_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(2))
                    set(Low_sld,'Value',Channel_Info(Channel).Z_Projection_Data.Normalized_Display_Limits(1))
                    warning on
                    set(HighDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(2)))
                    set(LowDisp,'String',num2str(Channel_Info(Channel).Z_Projection_Data.Display_Limits(1)))
                    %SetColorMap;
                    ColorBarDisplay(ViewerFig,ColorBarAxis,ColorBarAxisPosition);
                    HighContrast    
                    LowContrast
                else
                    set(ColorMapList,'Value',Channel_Info(Channel).DisplayColorMapIndex);
                    warning off
                    set(High_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                    set(Low_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(1))
                    warning on
                    set(HighDisp,'String',num2str(Channel_Info(Channel).Display_Limits(2)))
                    set(LowDisp,'String',num2str(Channel_Info(Channel).Display_Limits(1)))
                    %SetColorMap;
                    ColorBarDisplay(ViewerFig,ColorBarAxis,ColorBarAxisPosition);
                    HighContrast    
                    LowContrast
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %UpdateDisplay
                CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            catch
                WarningPopup = questdlg({'Unable to complete Z_Projection!'},'Problem Encountered!','OK','OK');
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(Z_ProjectionButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        function Merge_Z_Projection
            if Z_Projection_ContrastAdjusted
                f = waitbar(0,'Merging Z Projection Please wait...');
                fprintf('Merging Z_Projection...')
                count=0;
                warning off
                for t=1:size(Z_Projection_Data,2)
                    Z_Projection_Merge_Data(t).Proj=zeros(ImageHeight,ImageWidth,3,'single');
                    for c1=1:length(Channels2Merge)
                        c=Channels2Merge(c1);
                        Temp=squeeze(Z_Projection_Data(c,t).Proj);
                        [TempColor]=Stack_Viewer_Adjust_Contrast_and_Color(Temp,...
                            Channel_Info(c).Z_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(c).Z_Projection_Data.ContrastLow,...
                            Channel_Info(c).Z_Projection_Data.ContrastHigh,...
                            Channel_Info(c).Z_Projection_Data.ValueAdjust,...
                            Channel_Info(c).ColorScalar);
                        Z_Projection_Merge_Data(t).Proj=Z_Projection_Merge_Data(t).Proj+single(TempColor);
                        count=count+1;
                        if any(count==[1:round((length(Channels2Merge)*size(Z_Projection_Data,2))/TextUpdateIntervals):(length(Channels2Merge)*size(Z_Projection_Data,2))])
                            fprintf('.')
                            waitbar(count/(length(Channels2Merge)*size(Z_Projection_Data,2)),f,'Merging Z Projection Please wait...');
                        end
                    end
                end
                fprintf('Finished!\n');
                warning on
                waitbar(1,f,['Finished!']);
                close(f)
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %UpdateDisplay
                CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            end
            Z_Projection_ContrastAdjusted=0;
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function T_ProjectData(~,~,~)
            WasPlaying=PlayBack;
            if WasPlaying
                PausePlayStack(PauseButton);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            T_Projection=get(T_ProjectionButton,'value');
            set(T_ProjectionButton, 'Enable', 'off');
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            try
                if T_Projection
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    New_T_Projection=1;
                    if ~isempty(T_Projection_Data)
                        ReuseChoice = questdlg('Previous T_Projection_Data exists, Do you want to reuse?','Reuse Previous T_Projection_Data?','Reuse','New','Reuse');
                        if strcmp(ReuseChoice,'Reuse')
                            New_T_Projection=0;
                        elseif strcmp(ReuseChoice,'New')
                            New_T_Projection=1;
                        end
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    if New_T_Projection
                        T_Projection_ContrastAdjusted=1;
                        if ~RGB_Stack
                            if ~isfield(T_ProjectionSettings,'T_ProjectionChoice')
                                T_ProjectionSettings.T_ProjectionChoice=1;
                            end
                            [T_ProjectionSettings.T_ProjectionChoice, checking] = listdlg('PromptString',...
                                {'T_Projection Type'},'SelectionMode','single','ListString',T_ProjectionOptions,'ListSize', [200 200],'InitialValue',T_ProjectionSettings.T_ProjectionChoice);
                            T_ProjectionSettings.T_ProjectionType=T_ProjectionOptions{T_ProjectionSettings.T_ProjectionChoice};
    %                         [T_ProjectionSettings.T_ProjectionColorChoice, checking] = listdlg('PromptString',...
    %                             {'T_Projection Coloring'},'SelectionMode','single','ListString',T_ProjectionColoringOptions,'ListSize', [200 200],'InitialValue',1);
    %                         T_ProjectionSettings.T_ProjectionColoringMode=T_ProjectionOptions{T_ProjectionSettings.T_ProjectionColoringChoice};
                            if T_Stack
                                if ~isfield(T_ProjectionSettings,'T_Range')
                                    T_ProjectionSettings.T_Range=[1:Last_T];
                                end
                                T_ProjectionSettings.T_Options=[];
                                for tt=1:Last_T
                                    T_ProjectionSettings.T_Options{tt}=num2str(tt);
                                end
                                [T_ProjectionSettings.T_Range, checking] = listdlg('PromptString',{'Select T Range to Include'},...
                                    'SelectionMode','multiple','ListString',T_ProjectionSettings.T_Options,'ListSize', [200 600],'InitialValue',T_ProjectionSettings.T_Range);
                            else
                                T_ProjectionSettings.T_Range=[1];
                            end
                            if Z_Stack
                                T_ProjectionSettings.Z_Options=[];
                                for zz=1:Last_Z
                                    T_ProjectionSettings.Z_Options{zz}=num2str(zz);
                                end
%                                 [T_ProjectionSettings.Z_Range, checking] = listdlg('PromptString',{'Select Z Range to Include'},...
%                                     'SelectionMode','multiple','ListString',T_ProjectionSettings.Z_Options,'ListSize', [200 600],'InitialValue',[1:Last_Z]);
                                T_ProjectionSettings.Z_Range=[1:Last_Z];
                            else
                                T_ProjectionSettings.Z_Range=[1];
                            end
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                            f = waitbar(0,[T_ProjectionSettings.T_ProjectionType,' T Projection Please wait...']);
                            switch StackOrder
                                case 'YXZ'
                                    warning('No T Data!')
                                    T_Projection=0;
                                case 'YXT'
                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                    c=1;
                                    count=0;
                                    fprintf([T_ProjectionSettings.T_ProjectionType,' T Projecting Slices and Frames']);
                                    for t1=1:length(T_ProjectionSettings.T_Range)
                                        t=T_ProjectionSettings.T_Range(t1);
                                        T_Projection_Data(c,z).Stack=[];
                                        for z1=1:length(T_ProjectionSettings.Z_Range)
                                            z=T_ProjectionSettings.Z_Range(z1);
                                            %%%%%%%%%%%%%%%%%%
                                            %%%%%%%%%%%%%%%%%%
                                            TempImage=ImageArray(:,:,t);
                                            %%%%%%%%%%%%%%%%%%
                                            %%%%%%%%%%%%%%%%%%
                                            TempImage=squeeze(TempImage);
                                            T_Projection_Data(c,z).Stack=cat(3,...
                                                T_Projection_Data(c,z).Stack,TempImage);
                                            count=count+1;
                                            if any(count==[1:round((Last_Z*Last_T)/TextUpdateIntervals):(Last_Z*Last_T)])
                                                fprintf('.')
                                                waitbar(count/(Last_Z*Last_T),f,[T_ProjectionSettings.T_ProjectionType,' T Projection...']);
                                            end
                                        end
                                    end
                                    fprintf('Finished!\n');
                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                case 'YXC'
                                    warning('No T Data!')
                                    T_Projection=0;
                                    set(T_ProjectionButton,'value',T_Projection);
                                case 'YXZT'
                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                    c=1;
                                    count=0;
                                    fprintf([T_ProjectionSettings.T_ProjectionType,' T Projecting Slices and Frames']);
                                    for z1=1:length(T_ProjectionSettings.Z_Range)
                                        z=T_ProjectionSettings.Z_Range(z1);
                                        T_Projection_Data(c,z).Stack=[];
                                        for t1=1:length(T_ProjectionSettings.T_Range)
                                            t=T_ProjectionSettings.T_Range(t1);
                                            %%%%%%%%%%%%%%%%%%
                                            %%%%%%%%%%%%%%%%%%
                                            TempImage=ImageArray(:,:,z,t);
                                            %%%%%%%%%%%%%%%%%%
                                            %%%%%%%%%%%%%%%%%%
                                            TempImage=squeeze(TempImage);
                                            T_Projection_Data(c,z).Stack=cat(3,...
                                                T_Projection_Data(c,z).Stack,TempImage);
                                            count=count+1;
                                            if any(count==[1:round((Last_Z*Last_T)/TextUpdateIntervals):(Last_Z*Last_T)])
                                                fprintf('.')
                                                waitbar(count/(Last_Z*Last_T),f,[T_ProjectionSettings.T_ProjectionType,' T Projection...']);
                                            end
                                        end
                                    end
                                    fprintf('Finished!\n');
                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                case 'YXTZ'
                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                    c=1;
                                    count=0;
                                    fprintf([T_ProjectionSettings.T_ProjectionType,' T Projecting Slices and Frames']);
                                    for z1=1:length(T_ProjectionSettings.Z_Range)
                                        z=T_ProjectionSettings.Z_Range(z1);
                                        T_Projection_Data(c,z).Stack=[];
                                        for t1=1:length(T_ProjectionSettings.T_Range)
                                            t=T_ProjectionSettings.T_Range(t1);
                                            %%%%%%%%%%%%%%%%%%
                                            %%%%%%%%%%%%%%%%%%
                                            TempImage=ImageArray(:,:,t,z);
                                            %%%%%%%%%%%%%%%%%%
                                            %%%%%%%%%%%%%%%%%%
                                            TempImage=squeeze(TempImage);
                                            T_Projection_Data(c,z).Stack=cat(3,...
                                                T_Projection_Data(c,z).Stack,TempImage);
                                            count=count+1;
                                            if any(count==[1:round((Last_Z*Last_T)/TextUpdateIntervals):(Last_Z*Last_T)])
                                                fprintf('.')
                                                waitbar(count/(Last_Z*Last_T),f,[T_ProjectionSettings.T_ProjectionType,' T Projection...']);
                                            end
                                        end
                                    end
                                    fprintf('Finished!\n');
                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                case 'YXZC'
                                    warning('No T Data!')
                                    T_Projection=0;
                                    set(T_ProjectionButton,'value',T_Projection);
                                case 'YXCZ'
                                    warning('No T Data!')
                                    T_Projection=0;
                                    set(T_ProjectionButton,'value',T_Projection);
                                case 'YXTC'
                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                    for c=1:Last_C
                                        fprintf([T_ProjectionSettings.T_ProjectionType,' T Projecting ',Channel_Labels{c},' and Slices']);
                                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                        count=0;
                                        for z1=1:length(T_ProjectionSettings.Z_Range)
                                            z=T_ProjectionSettings.Z_Range(z1);
                                            T_Projection_Data(c,z).Stack=[];
                                            for t1=1:length(T_ProjectionSettings.T_Range)
                                                t=T_ProjectionSettings.T_Range(t1);
                                                %%%%%%%%%%%%%%%%%%
                                                %%%%%%%%%%%%%%%%%%
                                                TempImage=ImageArray(:,:,t,c);
                                                %%%%%%%%%%%%%%%%%%
                                                %%%%%%%%%%%%%%%%%%
                                                TempImage=squeeze(TempImage);
                                                T_Projection_Data(c,z).Stack=cat(3,...
                                                    T_Projection_Data(c,z).Stack,TempImage);
                                                count=count+1;
                                                if any(count==[1:round((Last_Z*Last_T)/TextUpdateIntervals):(Last_Z*Last_T)])
                                                    fprintf('.')
                                                    waitbar(count/(Last_Z*Last_T),f,[T_ProjectionSettings.T_ProjectionType,' T Projection ',Channel_Labels{c},'...']);
                                                end
                                            end
                                        end
                                        fprintf('Finished!\n');
                                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                    end
                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                case 'YXCT'
                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                    for c=1:Last_C
                                        fprintf([T_ProjectionSettings.T_ProjectionType,' T Projecting ',Channel_Labels{c},' and Slices']);
                                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                        count=0;
                                        for z1=1:length(T_ProjectionSettings.Z_Range)
                                            z=T_ProjectionSettings.Z_Range(z1);
                                            T_Projection_Data(c,z).Stack=[];
                                            for t1=1:length(T_ProjectionSettings.T_Range)
                                                t=T_ProjectionSettings.T_Range(t1);
                                                %%%%%%%%%%%%%%%%%%
                                                %%%%%%%%%%%%%%%%%%
                                                TempImage=ImageArray(:,:,c,t);
                                                %%%%%%%%%%%%%%%%%%
                                                %%%%%%%%%%%%%%%%%%
                                                TempImage=squeeze(TempImage);
                                                T_Projection_Data(c,z).Stack=cat(3,...
                                                    T_Projection_Data(c,z).Stack,TempImage);
                                                count=count+1;
                                                if any(count==[1:round((Last_Z*Last_T)/TextUpdateIntervals):(Last_Z*Last_T)])
                                                    fprintf('.')
                                                    waitbar(count/(Last_Z*Last_T),f,[T_ProjectionSettings.T_ProjectionType,' T Projection ',Channel_Labels{c},'...']);
                                                end
                                            end
                                        end
                                        fprintf('Finished!\n');
                                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                    end
                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                case 'YXZTC'
                                    for c=1:Last_C
                                        fprintf([T_ProjectionSettings.T_ProjectionType,' T Projecting ',Channel_Labels{c},' Slices and Frames']);
                                        count=0;
                                        for z1=1:length(T_ProjectionSettings.Z_Range)
                                            z=T_ProjectionSettings.Z_Range(z1);
                                            T_Projection_Data(c,z).Stack=[];
                                            for t1=1:length(T_ProjectionSettings.T_Range)
                                                t=T_ProjectionSettings.T_Range(t1);
                                                %%%%%%%%%%%%%%%%%%
                                                %%%%%%%%%%%%%%%%%%
                                                TempImage=ImageArray(:,:,z,t,c);
                                                %%%%%%%%%%%%%%%%%%
                                                %%%%%%%%%%%%%%%%%%
                                                TempImage=squeeze(TempImage);
                                                T_Projection_Data(c,z).Stack=cat(3,...
                                                    T_Projection_Data(c,z).Stack,TempImage);
                                                count=count+1;
                                                if any(count==[1:round((Last_Z*Last_T)/TextUpdateIntervals):(Last_Z*Last_T)])
                                                    fprintf('.')
                                                    waitbar(count/(Last_Z*Last_T),f,[T_ProjectionSettings.T_ProjectionType,' T Projection ',Channel_Labels{c},'...']);
                                                end
                                            end
                                        end
                                        fprintf('Finished!\n');
                                    end
                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                case 'YXTZC'
                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                    for c=1:Last_C
                                        fprintf([T_ProjectionSettings.T_ProjectionType,' T Projecting ',Channel_Labels{c},' Slices and Frames']);
                                        count=0;
                                        for z1=1:length(T_ProjectionSettings.Z_Range)
                                            z=T_ProjectionSettings.Z_Range(z1);
                                            T_Projection_Data(c,z).Stack=[];
                                            for t1=1:length(T_ProjectionSettings.T_Range)
                                                t=T_ProjectionSettings.T_Range(t1);
                                                %%%%%%%%%%%%%%%%%%
                                                %%%%%%%%%%%%%%%%%%
                                                TempImage=ImageArray(:,:,t,z,c);
                                                %%%%%%%%%%%%%%%%%%
                                                %%%%%%%%%%%%%%%%%%
                                                TempImage=squeeze(TempImage);
                                                T_Projection_Data(c,z).Stack=cat(3,...
                                                    T_Projection_Data(c,z).Stack,TempImage);
                                                count=count+1;
                                                if any(count==[1:round((Last_Z*Last_T)/TextUpdateIntervals):(Last_Z*Last_T)])
                                                    fprintf('.')
                                                    waitbar(count/(Last_Z*Last_T),f,[T_ProjectionSettings.T_ProjectionType,' T Projection ',Channel_Labels{c},'...']);
                                                end
                                            end
                                        end
                                        fprintf('Finished!\n');
                                    end
                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                case 'YX[RGB]T'
                                    T_Projection=0;
                                    set(T_ProjectionButton,'value',T_Projection);
                                case 'YXT[RGB]'
                                    T_Projection=0;
                                    set(T_ProjectionButton,'value',T_Projection);
                            end
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                            if T_Projection
                                for c=1:size(T_Projection_Data,1)
                                    for z=1:size(T_Projection_Data,2)
                                        switch T_ProjectionSettings.T_ProjectionType
                                            case 'Max'
                                                T_Projection_Data(c,z).Proj=...
                                                    max(T_Projection_Data(c,z).Stack,[],3);
                                            case 'Min'
                                                T_Projection_Data(c,z).Proj=...
                                                    min(T_Projection_Data(c,z).Stack,[],3);
                                            case 'Avg'
                                                T_Projection_Data(c,z).Proj=...
                                                    mean(T_Projection_Data(c,z).Stack,3);
                                            case 'Sum'
                                                T_Projection_Data(c,z).Proj=...
                                                    sum(T_Projection_Data(c,z).Stack,3);
                                        end
                                        T_Projection_Data(c,z).Stack=[];
                                    end
                                    Channel_Info(c).T_Projection_Data.ColorMaps.ColorMap=Channel_Info(c).ColorMap;
    %                                 switch T_ProjectionSettings.T_ProjectionColoringMode
    %                                     case 'Channel'
    %                                     case 'Graded'
    %                                         
    %                                         
    %                                 end
                                    Channel_Info(c).T_Projection_Data.Normalized_Display_Limits=Channel_Info(c).Normalized_Display_Limits;
                                    Channel_Info(c).T_Projection_Data.Display_Limits=Channel_Info(c).Display_Limits;
                                    Channel_Info(c).T_Projection_Data.ContrastLow=Channel_Info(c).ContrastLow;
                                    Channel_Info(c).T_Projection_Data.ContrastHigh=Channel_Info(c).ContrastHigh;
                                    Channel_Info(c).T_Projection_Data.ValueAdjust=Channel_Info(c).ValueAdjust;
                                end
                            end
                            waitbar(1,f,['Finished!']);
                            close(f)
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                            if MergeChannel
                                Merge_T_Projection
                            end
                            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        else
                            warning('Unable to project RGB Data!')
                            T_Projection=0;
                            set(T_ProjectionButton,'value',T_Projection);
                        end
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    set(ColorMapList,'Value',Channel_Info(Channel).DisplayColorMapIndex);
                    warning off
                    set(High_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(2))
                    set(Low_sld,'Value',Channel_Info(Channel).T_Projection_Data.Normalized_Display_Limits(1))
                    warning on
                    set(HighDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(2)))
                    set(LowDisp,'String',num2str(Channel_Info(Channel).T_Projection_Data.Display_Limits(1)))
                %SetColorMap;
                ColorBarDisplay(ViewerFig,ColorBarAxis,ColorBarAxisPosition);
                    HighContrast    
                    LowContrast
                else
                    set(ColorMapList,'Value',Channel_Info(Channel).DisplayColorMapIndex);
                    warning off
                    set(High_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(2))
                    set(Low_sld,'Value',Channel_Info(Channel).Normalized_Display_Limits(1))
                    warning on
                    set(HighDisp,'String',num2str(Channel_Info(Channel).Display_Limits(2)))
                    set(LowDisp,'String',num2str(Channel_Info(Channel).Display_Limits(1)))
                %SetColorMap;
                ColorBarDisplay(ViewerFig,ColorBarAxis,ColorBarAxisPosition);
                    HighContrast    
                    LowContrast
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %UpdateDisplay
                CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            catch
                WarningPopup = questdlg({'Unable to complete T_Projection!'},'Problem Encountered!','OK','OK');
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if WasPlaying
                StartPlayStack(PlayButton);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            set(T_ProjectionButton, 'Enable', 'on');
            set(ViewerFig,'CurrentObject',ViewerImageAxis)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        function Merge_T_Projection
            if T_Projection_ContrastAdjusted
                f = waitbar(0,'Merging T Projection Please wait...');
                fprintf('Merging T_Projection...')
                count=0;
                warning off
                for z=1:size(T_Projection_Data,2)
                    T_Projection_Merge_Data(z).Proj=zeros(ImageHeight,ImageWidth,3,'single');
                    for c1=1:length(Channels2Merge)
                        c=Channels2Merge(c1);
                        Temp=squeeze(T_Projection_Data(c,z).Proj);
                        [TempColor]=Stack_Viewer_Adjust_Contrast_and_Color(Temp,...
                            Channel_Info(c).T_Projection_Data.ColorMaps.ColorMap,...
                            Channel_Info(c).T_Projection_Data.ContrastLow,...
                            Channel_Info(c).T_Projection_Data.ContrastHigh,...
                            Channel_Info(c).T_Projection_Data.ValueAdjust,...
                            Channel_Info(c).ColorScalar);
                        T_Projection_Merge_Data(z).Proj=T_Projection_Merge_Data(z).Proj+single(TempColor);
                        count=count+1;
                        if any(count==[1:round((length(Channels2Merge)*size(T_Projection_Data,2))/TextUpdateIntervals):(length(Channels2Merge)*size(T_Projection_Data,2))])
                            fprintf('.')
                            waitbar(count/(length(Channels2Merge)*size(T_Projection_Data,2)),f,'Merging T Projection Please wait...');
                        end
                    end
                end
                fprintf('Finished!\n');
                warning on
                waitbar(1,f,['Finished!']);
                close(f)
            end
            T_Projection_ContrastAdjusted=0;
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function [ChannelSettings]=ChannelSelection(ChannelSettings)
            if C_Stack
                if isempty(Z_ProjectionSettings)
                    Z_ProjectionSettings.Z_ProjectionType='';
                else
                    if ~isfield(Z_ProjectionSettings,'Z_ProjectionType')
                        Z_ProjectionSettings.Z_ProjectionType='';
                    end
                end
                if isempty(T_ProjectionSettings)
                    T_ProjectionSettings.T_ProjectionType='';
                else
                    if ~isfield(T_ProjectionSettings,'T_ProjectionType')
                        T_ProjectionSettings.Z_ProjectionType='';
                    end
                end
                ChannelSettings.C_Option_Labels=horzcat(Channel_Labels,'Merge');
                ChannelSettings.C_Options=[1:Last_C,0];
                if Z_Stack
                    if ~isempty(Z_ProjectionSettings.Z_ProjectionType)
                        ChannelSettings.C_Option_Labels=horzcat(ChannelSettings.C_Option_Labels,['Merge ',Z_ProjectionSettings.Z_ProjectionType,' Z Project']);
                    else
                        ChannelSettings.C_Option_Labels=horzcat(ChannelSettings.C_Option_Labels,['Merge Z Project']);
                    end
                    ChannelSettings.C_Options=[ChannelSettings.C_Options,-1];
                end
                if T_Stack
                    if ~isempty(T_ProjectionSettings.T_ProjectionType)
                        ChannelSettings.C_Option_Labels=horzcat(ChannelSettings.C_Option_Labels,['Merge ',T_ProjectionSettings.T_ProjectionType,' T Project']);
                    else
                        ChannelSettings.C_Option_Labels=horzcat(ChannelSettings.C_Option_Labels,['Merge T Project']);
                    end
                    ChannelSettings.C_Options=[ChannelSettings.C_Options,-2];
                end
                for cc=1:length(ChannelSettings.C_Options)
                    ChannelSettings.C_Option_Colors{cc}='w';
                end
                for cc=1:length(Channel_Colors)
                    if ischar(Channel_Colors{cc})
                        if length(Channel_Colors{cc})==1
                            ChannelSettings.C_Option_Colors{cc}=Channel_Colors{cc};
                        else
                            ChannelSettings.C_Option_Colors{cc}='w';
                        end
                    else
                        ChannelSettings.C_Option_Colors{cc}=Channel_Colors{cc};
                    end
                end
                if MergeChannel&&~isempty(Z_Projection_Data)&&~isempty(T_Projection_Data)
                    DefaultChoices=[1:Last_C+3];
                elseif MergeChannel&&~isempty(Z_Projection_Data)&&isempty(T_Projection_Data)
                    DefaultChoices=[1:Last_C+2];
                elseif MergeChannel&&isempty(Z_Projection_Data)&&~isempty(T_Projection_Data)
                    DefaultChoices=[1:Last_C+2];
                elseif MergeChannel
                    DefaultChoices=[1:Last_C+1];
                elseif ~MergeChannel&&length(Channel_Colors)>1
                    DefaultChoices=[1:Last_C+1];
                else
                    DefaultChoices=[1:Last_C];
                end
                if ~isfield(ChannelSettings,'C_Option_Choices')
                    ChannelSettings.C_Option_Choices=DefaultChoices;
                end
                [ChannelSettings.C_Option_Choices, checking] = listdlg('PromptString',{'Select Channels to Include'},...
                    'SelectionMode','multiple','ListString',ChannelSettings.C_Option_Labels,'ListSize', [200 200],'InitialValue',ChannelSettings.C_Option_Choices);
                ChannelSettings.C_Range=ChannelSettings.C_Options(ChannelSettings.C_Option_Choices);
                for c1=1:length(ChannelSettings.C_Option_Choices)
                    c=ChannelSettings.C_Option_Choices(c1);
                    ChannelSettings.C_Colors{c1}=ChannelSettings.C_Option_Colors{c};
                end
                if length(ChannelSettings.C_Range)>1
                    ChannelSettings.C_Range_String=[mat2str(ChannelSettings.C_Range)];
                elseif length(ChannelSettings.C_Range)==1
                    ChannelSettings.C_Range_String=['[',mat2str(ChannelSettings.C_Range),']'];
                else
                    ChannelSettings.C_Range_String=['[]'];
                end
                if length(ChannelSettings.C_Range)>1
                    AdjustOrder = questdlg({'Adjust Channel Order?'},'Adjust Channel Order?','Good','Adjust','Good');
                    switch AdjustOrder
                        case 'Adjust'
                            for cc=1:length(ChannelSettings.C_Option_Labels)
                                disp(['Channel ',num2str(ChannelSettings.C_Options(cc)),': ',ChannelSettings.C_Option_Labels{cc}])
                            end
                            prompt = {'C_Range Order (0 Merge, -1 Merge Z Proj, -2 Merge T Proj)'};
                            dlg_title = 'C_Range Order';
                            num_lines = 1;
                            def = {ChannelSettings.C_Range_String};
                            answer = inputdlg(prompt,dlg_title,num_lines,def);
                            ChannelSettings.C_Range=ConvertString2Array(answer{1});
                            clear answer 
                    end
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                if any(ChannelSettings.C_Range==0)&&MergeChannel==0
                    set(MergeChannelButton,'value',1);
                    MergeChannelSetup
                    set(MergeChannelButton,'value',0);
                    MergeChannel=0;
                    %UpdateDisplay
                    CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                    [ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                ChannelSettings.C_Display=[];
                for c1=1:length(ChannelSettings.C_Range)
                    c=ChannelSettings.C_Range(c1);
                    if c~=0&&c~=-1&&c~=-2
                        ChannelSettings.C_Display{c1}=Channel_Labels{c};
                    elseif c==0
                        ChannelSettings.C_Display{c1}=['Merge'];
                    elseif c==-1
                        ChannelSettings.C_Display{c1}=['Merge ',Z_ProjectionSettings.Z_ProjectionType,' Z Proj'];
                    elseif c==-2
                        ChannelSettings.C_Display{c1}=['Merge ',T_ProjectionSettings.T_ProjectionType,' T Proj'];
                    end
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            else
                ChannelSettings.C_Range=[1];
                ChannelSettings.C_Colors{1}='w';
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if any(ChannelSettings.C_Range==-1)&&Z_Projection==0
                Z_Projection=1;
                set(Z_ProjectionButton,'value',Z_Projection);
                Z_ProjectData
                Merge_Z_Projection
                Z_Projection=0;
                set(Z_ProjectionButton,'value',Z_Projection);
                %UpdateDisplay
                %CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                %[ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            end
            if any(ChannelSettings.C_Range==-2)&&T_Projection==0
                T_Projection=1;
                set(T_ProjectionButton,'value',T_Projection);
                T_ProjectData
                Merge_T_Projection
                T_Projection=0;
                set(T_ProjectionButton,'value',T_Projection);
                %UpdateDisplay
                %CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                %[ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        function [SliceSettings]=SliceSelection(SliceSettings)
            if Z_Stack
                SliceSettings.Z_Options=[1:Last_Z,0];
                SliceSettings.Z_Option_Labels=[];
                for zz=1:Last_Z
                    SliceSettings.Z_Option_Labels{zz}=num2str(zz);
                end
                if ~isempty(Z_ProjectionSettings.Z_ProjectionType)
                    SliceSettings.Z_Option_Labels=horzcat(SliceSettings.Z_Option_Labels,[Z_ProjectionSettings.Z_ProjectionType,' Z Projection']);
                else
                    SliceSettings.Z_Option_Labels=horzcat(SliceSettings.Z_Option_Labels,['Z Projection']);
                end
                if Z_Projection
                    DefaultChoices=[1:Last_Z+1];
                else
                    DefaultChoices=[1:Last_Z];
                end
                if ~isfield(SliceSettings,'Z_Option_Choices')
                    SliceSettings.Z_Option_Choices=DefaultChoices;
                end
                [SliceSettings.Z_Option_Choices, checking] = listdlg('PromptString',{'Select Z_Range to Include'},...
                    'SelectionMode','multiple','ListString',SliceSettings.Z_Option_Labels,'ListSize', [200 600],'InitialValue',SliceSettings.Z_Option_Choices);
                SliceSettings.Z_Range=SliceSettings.Z_Options(SliceSettings.Z_Option_Choices);
                if length(SliceSettings.Z_Range)>1
                    SliceSettings.Z_Range_String=[mat2str(SliceSettings.Z_Range)];
                elseif length(SliceSettings.Z_Range)==1
                    SliceSettings.Z_Range_String=['[',mat2str(SliceSettings.Z_Range),']'];
                else
                    SliceSettings.Z_Range_String=['[]'];
                end
                if length(SliceSettings.Z_Range)>1
                    AdjustOrder = questdlg({'Adjust Slice Order?'},'Adjust Slice Order?','Good','Adjust','Good');
                    switch AdjustOrder
                        case 'Adjust'
                            prompt = {'                                Z_Range Order                                '};
                            dlg_title = 'Z_Range Order';
                            num_lines = 1;
                            def = {SliceSettings.Z_Range_String};
                            answer = inputdlg(prompt,dlg_title,num_lines,def);
                            SliceSettings.Z_Range=ConvertString2Array(answer{1});
                            clear answer
                    end
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                if any(SliceSettings.Z_Range==0)&&Z_Projection==0
                    set(Z_ProjectionButton,'value',1);
                    Z_ProjectData
                    set(Z_ProjectionButton,'value',0);
                    Z_Projection=0;
                    %UpdateDisplay
                    %CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                    %[ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                SliceSettings.Z_Display=[];
                for z1=1:length(SliceSettings.Z_Range)
                    z=SliceSettings.Z_Range(z1);
                    if z~=0
                        TempUnit=ImagingInfo.VoxelUnit;
                        if strcmp(TempUnit,'um')&&ForceGreekCharacter
                            TempUnit='\mum';
                        end
                        TempVoxel=num2str(ImagingInfo.VoxelDepth);
                        TempVoxDecimals=strfind(TempVoxel,'.');
                        TempZ=num2str(z);
                        if isempty(TempVoxDecimals)
                            TempZ=round((z-1)*ImagingInfo.VoxelDepth);
                            TempZ=num2str(TempZ);
                            TempZ=[TempZ];
                        elseif TempVoxDecimals==length(TempVoxel)-1
                            TempZ=round(z*ImagingInfo.VoxelDepth*10)/10;
                            TempZ=num2str(TempZ);
                            TempDecimals=strfind(TempZ,'.');
                            if isempty(TempDecimals)
                                TempZ=[TempZ,'.0'];
                            end
                        elseif TempVoxDecimals==length(TempVoxel)-2
                            TempZ=round((z-1)*ImagingInfo.VoxelDepth*100)/100;
                            TempZ=num2str(TempZ);
                            TempDecimals=strfind(TempZ,'.');
                            if isempty(TempDecimals)
                                TempZ=[TempZ,'.00'];
                            elseif TempDecimals==length(TempZ)-1
                                TempZ=[TempZ,'0'];
                            end
                        elseif TempVoxDecimals==length(TempVoxel)-3
                            TempZ=round((z-1)*ImagingInfo.VoxelDepth*1000)/1000;
                            TempZ=num2str(TempZ);
                            TempDecimals=strfind(TempZ,'.');
                            if isempty(TempDecimals)
                                TempZ=[TempZ,'.000'];
                            elseif TempDecimals==length(TempZ)-1
                                TempZ=[TempZ,'00'];
                            elseif TempDecimals==length(TempZ)-2
                                TempZ=[TempZ,'0'];
                            end
                        else
                            TempZ=round((z-1)*ImagingInfo.VoxelDepth*1000)/1000;
                            TempZ=num2str(TempZ);
                            TempDecimals=strfind(TempZ,'.');
                            if isempty(TempDecimals)
                                TempZ=[TempZ,'.000'];
                            elseif TempDecimals==length(TempZ)-1
                                TempZ=[TempZ,'00'];
                            elseif TempDecimals==length(TempZ)-2
                                TempZ=[TempZ,'0'];
                            end
                        end
                        SliceSettings.Z_Display{z1}=['Z=',num2str(z),' ',TempZ,' ',TempUnit];
                    else
                        SliceSettings.Z_Display{z1}=[Z_ProjectionSettings.Z_ProjectionType,' Z Projection'];
                    end
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            else
                SliceSettings.Z_Range=[1];
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if any(SliceSettings.Z_Range==0)&&Z_Projection==0
                Z_Projection=1;
                set(Z_ProjectionButton,'value',Z_Projection);
                Z_ProjectData
                Merge_Z_Projection
                Z_Projection=0;
                set(Z_ProjectionButton,'value',Z_Projection);
                %UpdateDisplay
                %CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                %[ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        function [FrameSettings]=FrameSelection(FrameSettings)
            if T_Stack
                FrameSettings.T_Options=[1:Last_T,0];
                FrameSettings.T_Option_Labels=[];
                for zz=1:Last_T
                    FrameSettings.T_Option_Labels{zz}=num2str(zz);
                end
                if ~isempty(T_ProjectionSettings.T_ProjectionType)
                    FrameSettings.T_Option_Labels=horzcat(FrameSettings.T_Option_Labels,[Z_ProjectionSettings.T_ProjectionType,' T Projection']);
                else
                    FrameSettings.T_Option_Labels=horzcat(FrameSettings.T_Option_Labels,['T Projection']);
                end
                if T_Projection
                    DefaultChoices=[1:Last_T+1];
                else
                    DefaultChoices=[1:Last_T];
                end
                if ~isfield(FrameSettings,'T_Option_Choices')
                    FrameSettings.T_Option_Choices=DefaultChoices;
                end
                [FrameSettings.T_Option_Choices, checking] = listdlg('PromptString',{'Select T_Range to Include'},...
                    'SelectionMode','multiple','ListString',FrameSettings.T_Option_Labels,'ListSize', [200 600],'InitialValue',FrameSettings.T_Option_Choices);
                FrameSettings.T_Range=FrameSettings.T_Options(FrameSettings.T_Option_Choices);
                if length(FrameSettings.T_Range)>1
                    FrameSettings.T_Range_String=[mat2str(FrameSettings.T_Range)];
                elseif length(FrameSettings.T_Range)==1
                    FrameSettings.T_Range_String=['[',mat2str(FrameSettings.T_Range),']'];
                else
                    FrameSettings.T_Range_String=['[]'];
                end
                if length(FrameSettings.T_Range)>1
                    AdjustOrder = questdlg({'Adjust Frame Order?'},'Adjust Frame Order?','Good','Adjust','Good');
                    switch AdjustOrder
                        case 'Adjust'
                            prompt = {'                                T_Range Order                                '};
                            dlg_title = 'T_Range Order';
                            num_lines = 1;
                            def = {FrameSettings.T_Range_String};
                            answer = inputdlg(prompt,dlg_title,num_lines,def);
                            FrameSettings.T_Range=ConvertString2Array(answer{1});
                            clear answer
                    end
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                FrameSettings.T_Display=[];
                for t1=1:length(FrameSettings.T_Range)
                    t=FrameSettings.T_Range(t1);
                    if t~=0
                        if ~isnan(ImagingInfo.InterFrameTime)
                            TempFrameInterval=num2str(ImagingInfo.InterFrameTime);
                            TempFrameDecimals=strfind(TempFrameInterval,'.');
                            if isempty(TempFrameDecimals)
                                TempT=round((t-1)*ImagingInfo.InterFrameTime);
                                TempT=num2str(TempT);
                                TempT=[TempT];
                            elseif TempFrameDecimals==length(TempFrameInterval)-1
                                TempT=round((t-1)*ImagingInfo.InterFrameTime*10)/10;
                                TempT=num2str(TempT);
                                TempDecimals=strfind(TempT,'.');
                                if isempty(TempDecimals)
                                    TempT=[TempT,'.0'];
                                end
                            elseif TempFrameDecimals==length(TempFrameInterval)-2
                                TempT=round((t-1)*ImagingInfo.InterFrameTime*100)/100;
                                TempT=num2str(TempT);
                                TempDecimals=strfind(TempT,'.');
                                if isempty(TempDecimals)
                                    TempT=[TempT,'.00'];
                                elseif TempDecimals==length(TempT)-1
                                    TempT=[TempT,'0'];
                                end
                            elseif TempFrameDecimals==length(TempFrameInterval)-3
                                TempT=round((t-1)*ImagingInfo.InterFrameTime*1000)/1000;
                                TempT=num2str(TempT);
                                TempDecimals=strfind(TempT,'.');
                                if isempty(TempDecimals)
                                    TempT=[TempT,'.000'];
                                elseif TempDecimals==length(TempT)-1
                                    TempT=[TempT,'00'];
                                elseif TempDecimals==length(TempT)-2
                                    TempT=[TempT,'0'];
                                end
                            end
                            FrameSettings.T_Display{t1}=['T=',num2str(t),' ',TempT,ImagingInfo.FrameUnit];
                        else
                            FrameSettings.T_Display{t1}=['T=',num2str(t)];
                        end
                    else
                        FrameSettings.T_Display{t1}='T Projection';
                    end
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            else
                FrameSettings.T_Range=[1];
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if any(FrameSettings.T_Range==0)&&T_Projection==0
                T_Projection=1;
                set(T_ProjectionButton,'value',T_Projection);
                T_ProjectData
                Merge_T_Projection
                T_Projection=0;
                set(T_ProjectionButton,'value',T_Projection);
                %UpdateDisplay
                %CurrentImages=FindCurrentImage(Channel,Frame,Slice,StackOrder,Z_Projection,T_Projection,MergeChannel,0,TileChannels,TileSlices,TileFrames,TileSettings);
                %[ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes]=ImageDisplay(Channel,Frame,Slice,CurrentImages,ViewerFig,ViewerImageAxis,ViewerImageAxisPosition,MaskAxes,TileAxes,ViewerFigPosition);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function ColorCode=ColorDefinitionsLookup(ColorAbbreviation)
            %ColorDefinitions('m')
            % [1 1 0]y
            % [1 0 1]m
            % [0 1 1]c
            % [1 0 0]r
            % [0 1 0]g
            % [0 0 1]b
            % [1 1 1]w
            % [0 0 0]k
            if ischar(ColorAbbreviation)
                BasicColors={'y' 'm' 'c' 'r' 'g' 'b' 'w' 'k'};
                BasicColorCodes={[1 1 0] [1 0 1] [0 1 1] [1 0 0] [0 1 0] [0 0 1] [1 1 1] [0 0 0]};
                ColorCode=[1 1 1];
                for i=1:length(BasicColors)
                    if strcmp(BasicColors{i},ColorAbbreviation)
                        ColorCode=BasicColorCodes{i};
                    end
                end
            else
                ColorCode=ColorAbbreviation;
            end
        end
        function ColorAbbreviation=ColorAbbreviationLookup(ColorCode)
            %ColorDefinitionsLookup('m')
            % [1 1 0]y
            % [1 0 1]m
            % [0 1 1]c
            % [1 0 0]r
            % [0 1 0]g
            % [0 0 1]b
            % [1 1 1]w
            % [0 0 0]k

            BasicColors={'y' 'm' 'c' 'r' 'g' 'b' 'w' 'k'};
            BasicColorCodes={[1 1 0] [1 0 1] [0 1 1] [1 0 0] [0 1 0] [0 0 1] [1 1 1] [0 0 0]};
            ColorAbbreviation=NaN;
            for i=1:length(BasicColorCodes)
                if any(BasicColorCodes{i}~=ColorCode)
                else
                    ColorAbbreviation=BasicColors{i};
                end
            end
        end
        function [cMap,ValueAdjust,ContrastHigh,ContrastLow]=...
                StackViewer_UniversalColorMap(ColorString,ColorCode,Display_Limits,ColorScalar)
            if Display_Limits(2)-Display_Limits(1)<=0
                ValueAdjust=0;
                ContrastHigh=2;
                ContrastLow=0;
            else
                ValueAdjust=abs(Display_Limits(1));
                ContrastHigh=...
                    round((Display_Limits(2)+...
                    ValueAdjust)*ColorScalar)+1;
                ContrastLow=...
                    round((Display_Limits(1)+...
                    ValueAdjust)*ColorScalar)+1;
            end
            if (ContrastHigh-ContrastLow)<=0
                warning on
                warning('Provide StackViewer_UniversalColorMap with separated contrast values!')
                error('Provide StackViewer_UniversalColorMap with separated contrast values!')
            end
            try
                if ischar(ColorString)
                    if length(ColorString)==1
                        cMap=makeColorMap([0 0 0],ColorDefinitionsLookup(ColorString),round(ContrastHigh-ContrastLow));
                    else
                        if any(contains(ColorString,'gray'))||any(contains(ColorString,'grays'))
                            cMap=gray(round(ContrastHigh-ContrastLow));
                        elseif any(contains(ColorString,'jet'))
                            cMap=jet(round(ContrastHigh-ContrastLow));
                        elseif any(contains(ColorString,'parula'))
                            cMap=parula(round(ContrastHigh-ContrastLow));
                        elseif any(contains(ColorString,'hsv'))
                            cMap=hsv(round(ContrastHigh-ContrastLow));
                        elseif any(contains(ColorString,'hot'))
                            cMap=hot(round(ContrastHigh-ContrastLow));
                        elseif any(contains(ColorString,'cool'))
                            cMap=cool(round(ContrastHigh-ContrastLow));
                        elseif any(contains(ColorString,'spring'))
                            cMap=spring(round(ContrastHigh-ContrastLow));
                        elseif any(contains(ColorString,'summer'))
                            cMap=summer(round(ContrastHigh-ContrastLow));
                        elseif any(contains(ColorString,'autumn'))
                            cMap=autumn(round(ContrastHigh-ContrastLow));
                        elseif any(contains(ColorString,'winter'))
                            cMap=winter(round(ContrastHigh-ContrastLow));
                        elseif any(contains(ColorString,'bone'))
                            cMap=bone(round(ContrastHigh-ContrastLow));
                        elseif any(contains(ColorString,'copper'))
                            cMap=copper(round(ContrastHigh-ContrastLow));
                        elseif any(contains(ColorString,'pink'))
                            cMap=pink(round(ContrastHigh-ContrastLow));
                        elseif any(contains(ColorString,'lines'))
                            cMap=lines(round(ContrastHigh-ContrastLow));
                        elseif any(contains(ColorString,'colorcube'))
                            cMap=colorcube(round(ContrastHigh-ContrastLow));
                        elseif any(contains(ColorString,'prism'))
                            cMap=prism(round(ContrastHigh-ContrastLow));
                        elseif any(contains(ColorString,'flag'))
                            cMap=flag(round(ContrastHigh-ContrastLow));
                        else
                            warning('Missing Color Code Needs to be [0,1,1], r or jet/parula/hot/gray')
                            error('Fix Color Code...')
                        end
                    end
                elseif length(ColorCode)==3
                    cMap=makeColorMap([0 0 0],ColorCode,round(ContrastHigh-ContrastLow));
                else
                    warning('Missing Color Code Needs to be [0,1,1], r or jet/parula/hot/gray')
                    error('Fix Color Code...')
                end
            catch
                cMap=makeColorMap([0 0 0],ColorCode,round(ContrastHigh-ContrastLow));
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function [OutputArray]=ConvertString2Array(varargin)
            Delimiters=[];
            StartCap=[];
            EndCap=[];
            switch nargin
                case 1
                    InputString=varargin{1};
                case 2
                    InputString=varargin{1};
                    Delimiters=varargin{2};
                case 3
                    InputString=varargin{1};
                    Delimiters=varargin{2};
                    StartCap=varargin{3};
                case 4
                    InputString=varargin{1};
                    Delimiters=varargin{2};
                    StartCap=varargin{3};
                    EndCap=varargin{4};
            end

            if ~exist('Delimiters')
                Delimiters={' ',','};
            end
            if isempty(Delimiters)
                Delimiters={' ',','};
            end
            if ~exist('StartCap')
                StartCap='[';
            end
            if isempty(StartCap)
                StartCap='[';
            end
            if ~exist('EndCap')
                EndCap=']';
            end
            if isempty(EndCap)
                EndCap=']';
            end

            NumChar=length(InputString);
            OutputArray=[];
            OutputElement=0;
            TempString=[];
            FinishedElement=0;
            for i=1:NumChar
                TempDigit=InputString(i);
                if ~strcmp(TempDigit,StartCap)
                    GoodEntry=1;
                    for j=1:length(Delimiters)
                        if strcmp(TempDigit,Delimiters{j})
                            GoodEntry=0;
                            FinishedElement=1;
                        elseif strcmp(TempDigit,EndCap)
                            GoodEntry=0;
                            FinishedElement=1;
                        end
                    end
                    if GoodEntry
                        TempString=strcat(TempString,TempDigit);
                    end
                end
                if FinishedElement
                    OutputElement=OutputElement+1;
                    if ischar(TempString)
                    OutputArray(OutputElement)=str2num(TempString);
                    end
                    TempString=[];
                    FinishedElement=0;
                end
            end

        end
        function [Num_Bins,Bin_Edges,Bin_Labels,Bin_Centers,Histogram,Normalized_Histogram,...
            Cumulative_Histogram,Normalized_Cumulative_Histogram]=ImageHistograms(Data,Bin_Range,Bin_Size)
            if Bin_Range(1)==Bin_Range(2)
                warning('No unique data present')
                warning('No unique data present')
                warning('No unique data present')
                warning('No unique data present')
                Num_Bins=[];
                Bin_Edges=[];
                Bin_Labels=[];
                Bin_Centers=[];
                Histogram=[];
                Normalized_Histogram=[];
                Cumulative_Histogram=[];
                Normalized_Cumulative_Histogram=[];
            else
                if any(Data==Inf)
                    warning on
                    warning('Removing Inf values!')
                    Data(Data==Inf)=NaN;
                end
                if any(~isnan(Data))

                    if isempty(Bin_Range)
                        if min(Data(:))<0&&abs(max(Data(:))-min(Data(:)))>10
                            MinBin=floor(min(Data(:)));
                        elseif min(Data(:))<0
                            MinBin=floor(min(Data(:))*100)/100;
                        else
                            MinBin=0;
                        end
                        if abs(max(Data(:))-min(Data(:)))>10
                            MaxBin=ceil(max(Data(:)));
                        else
                            MaxBin=ceil(max(Data(:))*100)/100;
                        end
                        Bin_Range=[MinBin,MaxBin];

                    end
                    if isempty(Bin_Size)
                        Bin_Size=abs(Bin_Range(2)-Bin_Range(1))/100;
                    end
                    if Bin_Size>max(abs(Bin_Range))
                        error('Bins are larger than range!')
                    end
                    Bin_Edges=[Bin_Range(1):Bin_Size:Bin_Range(2)];
                    Num_Bins=length(Bin_Edges)-1;
                    for Bin=1:Num_Bins
                        if Bin<Num_Bins
                            Bin_Labels{Bin}=[num2str(Bin_Edges(Bin)),'<=x<',num2str(Bin_Edges(Bin+1))];
                        else
                            Bin_Labels{Bin}=[num2str(Bin_Edges(Bin)),'<=x<=',num2str(Bin_Edges(Bin+1))];
                        end
                        Bin_Centers(Bin)=(Bin_Edges(Bin+1)-Bin_Edges(Bin))/2+Bin_Edges(Bin);
                    end
                    if length(Bin_Edges)>1
                        Histogram=histcounts(Data,Bin_Edges);
                        Normalized_Histogram=Histogram/max(Histogram);
                        Cumulative_Histogram=cumsum(Histogram);
                        Normalized_Cumulative_Histogram=Cumulative_Histogram/max(Cumulative_Histogram);
                    else
                        Num_Bins=[];
                        Bin_Edges=[];
                        Bin_Labels=[];
                        Bin_Centers=[];

                        Histogram=[];
                        Normalized_Histogram=[];
                        Cumulative_Histogram=[];
                        Normalized_Cumulative_Histogram=[];
                    end
                else
                    %warning('No Non-NAN values present in data....')
                    Num_Bins=[];
                    Bin_Edges=[];
                    Bin_Labels=[];
                    Bin_Centers=[];

                    Histogram=[];
                    Normalized_Histogram=[];
                    Cumulative_Histogram=[];
                    Normalized_Cumulative_Histogram=[];
                end
            end
        end
        function [BorderLine]=FindROIBorders(DataRegion,DilateDataRegion)
            BorderLine=[];
            if length(size(DataRegion))>2
                DataRegionProj=max(max(max(DataRegion,[],3),[],4),[],5);
            else
                DataRegionProj=DataRegion;
            end
            if ~isempty(DilateDataRegion)
                [B,L] = bwboundaries(imdilate(logical(DataRegionProj),DilateDataRegion),'noholes');
            else
                [B,L] = bwboundaries(logical(DataRegionProj),'noholes');
            end
            for j=1:length(B)
                for k = 1:length(B{j})
                    BorderLine{j}.BorderLine(k,:) = B{j}(k,:);
                end
            end
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Functions from Other folks
        function cMap = makeColorMap(varargin)
        % MAKECOLORMAP makes smoothly varying colormaps
        % Copyright 2008 - 2009 The MathWorks, Inc.
        % a = makeColorMap(beginColor, middleColor, endColor, numSteps);
        % a = makeColorMap(beginColor, endColor, numSteps);
        % a = makeColorMap(beginColor, middleColor, endColor);
        % a = makeColorMap(beginColor, endColor);
        %
        % all colors are specified as RGB triples
        % numSteps is a scalar saying howmany points are in the colormap
        %
        % Examples:
        %
        % peaks;
        % a = makeColorMap([1 0 0],[1 1 1],[0 0 1],40);
        % colormap(a)
        % colorbar
        %
        % peaks;
        % a = makeColorMap([1 0 0],[0 0 1],40);
        % colormap(a)
        % colorbar
        %
        % peaks;
        % a = makeColorMap([1 0 0],[1 1 1],[0 0 1]);
        % colormap(a)
        % colorbar
        %
        % peaks;
        % a = makeColorMap([1 0 0],[0 0 1]);
        % colormap(a)
        % colorbar

        % Reference:
        % A. Light & P.J. Bartlein, "The End of the Rainbow? Color Schemes for
        % Improved Data Graphics," Eos,Vol. 85, No. 40, 5 October 2004.
        % http://geography.uoregon.edu/datagraphics/EOS/Light&Bartlein_EOS2004.pdf

        defaultNum = 100;
        errorMessage = 'See help MAKECOLORMAP for correct input arguments';

        if nargin == 2 %endPoints of colormap only
            color.start  = varargin{1};
            color.middle = [];
            color.end    = varargin{2};
            color.num    = defaultNum;
        elseif nargin == 4 %endPoints, midPoint, and N defined
            color.start  = varargin{1};
            color.middle = varargin{2};
            color.end    = varargin{3};
            color.num    = varargin{4};
        elseif nargin == 3 %endPoints and num OR endpoints and Mid
            if numel(varargin{3}) == 3 %color
                color.start  = varargin{1};
                color.middle = varargin{2};
                color.end    = varargin{3};
                color.num    = defaultNum;
            elseif numel(varargin{3}) == 1 %numPoints
                color.start  = varargin{1};
                color.middle = [];
                color.end    = varargin{2};
                color.num    = varargin{3};
            else
                error(errorMessage)
            end
        else
            error(errorMessage)
        end

        if color.num <= 1
            error(errorMessage)
        end

        if isempty(color.middle) %no midPoint
            cMap = interpMap(color.start, color.end, color.num);
        else %midpointDefined
            [topN, botN] = sizePartialMaps(color.num);
            cMapTop = interpMap(color.start, color.middle, topN);
            cMapBot = interpMap(color.middle, color.end, botN);
            cMap = [cMapTop(1:end-1,:); cMapBot];
        end
        end
        function cMap = interpMap(colorStart, colorEnd, n)

        for i = 1:3
            cMap(1:n,i) = linspace(colorStart(i), colorEnd(i), n);
        end
        end
        function [topN, botN] = sizePartialMaps(n)
        n = n + 1;

        topN =  ceil(n/2);
        botN = floor(n/2);
        end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %This should help keep ROIPOLY from breaking everything
    while ~ReleaseFig&&isvalid(ViewerFig)
        if ~ExitViewer&&isvalid(ViewerFig)
            uiwait(ViewerFig);
%         else
%             uiresume(ViewerFig);
%             close(ViewerFig);
%             try
%                 close(TrackerFig);
%             catch
%             end
%             ReleaseFig=1;
        end
    end
end
