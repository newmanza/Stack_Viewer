%To DO
%BFReader release .tif for delete from scratch disk
% DataRegion/Stitch Mask
% CZI import
function [FileID,FileName,RawDataDir,ScratchDir,ImageArray,DataRegion,StackOrder,...
    MetaData,Additional_MetaData,BasicFileData,Channel_Labels,Channel_Colors,Channel_Color_Codes]=Stack_Import(varargin)
% 
% 
% 
    TurboMode=0;
    RawDataDir=[];
    LoadDir=[];
    ScratchDir=[];
    ChannelSelection=[];
    SaveDir=[];
    FileName=[];
    DataRegion=[];
    PreviousMetaData=0;
    PartialMetaData=0;
    Additional_MetaData=[];
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if nargin==0
        FileName=[];
        LoadDir=[];
        ScratchDir=[];
        ChannelSelection=[];
        TurboMode=0;
    elseif nargin==1
        FileName=varargin{1};
        LoadDir=[];
        ScratchDir=[];
        ChannelSelection=[];
        TurboMode=0;
    elseif nargin==2
        FileName=varargin{1};
        LoadDir=varargin{2};
        ScratchDir=[];
        ChannelSelection=[];
        TurboMode=0;
    elseif nargin==3
        FileName=varargin{1};
        LoadDir=varargin{2};
        ScratchDir=varargin{3};
        ChannelSelection=[];
        TurboMode=0;
    elseif nargin==4
        FileName=varargin{1};
        LoadDir=varargin{2};
        ScratchDir=varargin{3};
        ChannelSelection=varargin{4};
        TurboMode=0;
    elseif nargin==5
        FileName=varargin{1};
        LoadDir=varargin{2};
        ScratchDir=varargin{3};
        ChannelSelection=varargin{4};
        TurboMode=varargin{5};
    elseif nargin==6
        FileName=varargin{1};
        LoadDir=varargin{2};
        ScratchDir=varargin{3};
        ChannelSelection=varargin{4};
        TurboMode=varargin{5};
        MetaData=varargin{6};
        if ~isempty(MetaData)
            Objective=MetaData.Objective;
            StackSizeX=MetaData.StackSizeX;
            StackSizeY=MetaData.StackSizeY;
            StackSizeZ=MetaData.StackSizeZ;
            StackSizeT=MetaData.StackSizeT;
            StackSizeC=MetaData.StackSizeC;
            ChannelList=MetaData.ChannelList;
            PlaneSpacing=MetaData.PlaneSpacing;
            ScaleFactor=MetaData.ScaleFactor;
            ScalingX=MetaData.ScalingX;
            ScalingY=MetaData.ScalingY;
            ScalingT=MetaData.ScalingT;
            ScalingZ=MetaData.ScalingZ;
            StackOrder=MetaData.StackOrder;
            if isfield(MetaData,'DataClass')
                DataClass=MetaData.DataClass;
            else
                DataClass='uint16';
            end
            if isempty(StackSizeX)&&isempty(ScalingX)
                PreviousMetaData=0;
                PartialMetaData=0;
            elseif isempty(StackSizeX)&&~isempty(ScalingX)
                PreviousMetaData=0;
                PartialMetaData=1;
            else
                PreviousMetaData=1;
            end
        end
    else
        error('Inappropraite inputs')
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if ~isempty(ScratchDir)
        Save2Scratch=1;
    else
        Save2Scratch=0;
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    StartingDir=cd;
    if isempty(LoadDir)
        LoadDir = cd;
        [upperPath, deepestFolder] = fileparts(LoadDir);
    end
    if LoadDir(length(LoadDir))~=dc
        LoadDir=[LoadDir,dc];
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %GET FILE IF NOT IN FUNCTION CALL
    if isempty(FileName)
        [FileName,LoadDir]=uigetfile({'*.tif;*.lsm;*.czi', 'All SUPPORTED IMAGE Files (*.tif *.lsm *.czi)'});
    elseif isempty(FileName)
        [FileName,LoadDir]=uigetfile({'*.tif;*.lsm;*.czi', 'All SUPPORTED IMAGE Files (*.tif *.lsm *.czi)'});
    end
    cd(LoadDir)
    [upperPath, deepestFolder] = fileparts(LoadDir);
    RawDataDir=LoadDir;
    SaveDir=LoadDir;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if isempty(ScratchDir)
        if ~TurboMode
            ScratchChoice = questdlg({'If DATA is being stored on a server or external drive';...
                                      'I find it helpful to copy the data to a local directory';
                                      'to speed up loading and file saving';...
                                      'Do you want to load from a Temporary Scratch Directory?'},...
                                      'Scratch Dir?','Use Scratch','Skip','Skip');
            switch ScratchChoice
                case 'Use Scratch'
                    Save2Scratch=1;
                case 'Skip'
                    Save2Scratch=0;
            end
        else
            Save2Scratch=0;
        end
        if Save2Scratch
            ScratchDir=uigetdir(LoadDir,['Please Select Temporary Scratch Destination Directory']);
        else
            ScratchDir=[];
            LoadDir=RawDataDir;
            SaveDir=LoadDir;
        end
    else
        LoadDir=RawDataDir;
        SaveDir=LoadDir;
    end
    if Save2Scratch
        Copy2Scratch=1;
        if exist([ScratchDir,dc,FileName])
            Copy2ScratchChoice = questdlg({FileName;'Already Exists In:';ScratchDir;'Overwrite data?'},'Overwrite?','Overwrite','Skip','Skip');
            if isempty(Copy2ScratchChoice)
                error('Need a choice')
            else
                switch Copy2ScratchChoice
                    case 'Overwrite'
                        Copy2Scratch=1;
                    case 'Skip'
                        Copy2Scratch=0;
                end
            end
        end
        if Copy2Scratch
            fprintf(['Copying ',FileName,' To ScratchDir...'])
            [CopyStatus,CopyMessage]=copyfile([RawDataDir,FileName],ScratchDir);
            if CopyStatus
                fprintf('Copy successful!\n')
                LoadDir=[ScratchDir,dc];
                SaveDir=LoadDir;
            else
                warning(CopyMessage)
                Save2Scratch=0;
                ScratchDir=[];
                LoadDir=RawDataDir;
                SaveDir=LoadDir;
            end
        else
           warning('Skipping copy...') 
        end
    end
    cd(StartingDir)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Test for file extension
    FileType=0; %1 .tif 2 .lsm 3 .czi
    if ~strcmp(FileName(length(FileName)-3),'.')
        if exist(strcat([LoadDir,dc,FileName],'.tif'))
            FileName=strcat(FileName,'.tif');
            FileID=FileName(1:length(FileName)-4);
            FileType=1;
        elseif exist(strcat([LoadDir,dc,FileName],'.lsm'))
            FileName=strcat(FileName,'.lsm');
            FileID=FileName(1:length(FileName)-4);
            FileType=2;
        elseif exist(strcat([LoadDir,dc,FileName],'.czi'))
            FileName=strcat(FileName,'.czi');
            FileID=FileName(1:length(FileName)-4);
            FileType=3;
        else
            error('Incompatible file type or file not found!')
        end
    else
        if exist([LoadDir,dc,FileName])
            if any(strfind(FileName,'.tif'))
                FileType=1;
            elseif any(strfind(FileName,'.lsm'))
                FileType=2;
            elseif any(strfind(FileName,'.czi'))
                FileType=3;
            else
                error('Incompatible file type!')
            end    
            FileID=FileName(1:length(FileName)-4);
        else
            error('FILE NOT FOUND!')
        end
    end
    
    if ~exist([LoadDir,dc,FileName],'file')
        disp(['FILE NOT FOUND: ',FileName])
        disp('Terminating script')
        return;return;
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    disp('==============================================')
    disp('==============================================')
    disp('==============================================')
    disp(['Starting Processing on ',FileName])
    if FileType==1
        disp('Using settings for .tif file import!')
    elseif FileType==2
        disp('Using settings for .lsm file import!')
    elseif FileType==3
        disp('Using settings for .czi file import!')
    end
    disp('==============================================')
    disp('==============================================')
    disp('==============================================')
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Load Meta Data
    BasicFileData.FileName=FileName;
    BasicFileData.imfinf=[];
    BasicFileData.lsminf=[];
    BasicFileData.scaninf=[];
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if ~PreviousMetaData
        Objective=[];
        MetaData=[];
        Additional_MetaData=[];
        StackSizeX=1;
        StackSizeY=1;
        StackSizeT=1;
        StackSizeZ=1;
        StackSizeC=1;
        if ~PartialMetaData
            StackOrder='YX';
            ScalingX=0;
            ScalingY=0;
            ScalingZ=0;
            ScalingT=0;
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        switch FileType
            case 1
                %Load metadata from .tif file
                temp=imreadBF([LoadDir,dc,FileName],1,1,1);
                clear temp
                imfinf=imfinfo([LoadDir,dc,FileName]);
                TotalImages=size(imfinf,1);
                BitDepth=imfinf(1).BitsPerSample;
                TestImage=imread([LoadDir,dc,FileName],1);
                DataClass='double';
                if BitDepth==16
                    DataClass='uint16';
                elseif BitDepth==8
                    DataClass='uint8';
                end
                if any(TestImage(:)<0)
                    warning('Negative values, converting to double')
                    BitDepth=16;
                    DataClass='double';
                end
                StackSizeX=imfinf(1).Width;
                StackSizeY=imfinf(1).Height;
                StackSizeT=1;
                StackSizeZ=1;
                StackSizeC=1;
                ImageDescription=imfinf(1).ImageDescription;
                ChannelText='channels=';
                ChannelLoc=strfind(ImageDescription,ChannelText);
                BadMatch=1;
                TestCount=0;
                while BadMatch
                    if isempty(str2num(ImageDescription((ChannelLoc+length(ChannelText)):(ChannelLoc+length(ChannelText)+TestCount))))
                        BadMatch=0;
                        StackSizeC=str2num(ImageDescription((ChannelLoc+length(ChannelText)):(ChannelLoc+length(ChannelText)+(TestCount-1))));
                    else
                        TestCount=TestCount+1;
                    end
                end  
                if isempty(StackSizeC)
                    StackSizeC=1;
                end
                SliceText='slices=';
                SliceLoc=strfind(ImageDescription,SliceText);
                BadMatch=1;
                TestCount=0;
                while BadMatch&&TestCount<10
                    if isempty(str2num(ImageDescription((SliceLoc+length(SliceText)):(SliceLoc+length(SliceText)+TestCount))))
                        BadMatch=0;
                        StackSizeZ=str2num(ImageDescription((SliceLoc+length(SliceText)):(SliceLoc+length(SliceText)+(TestCount-1))));
                    else
                        TestCount=TestCount+1;
                    end
                end
                try
                    reader = loci.formats.Memoizer(bfGetReader(), 0);
                    reader.setId([LoadDir,dc,FileName])
                    OME_MetaData = reader.getMetadataStore();
                    StackSizeX = OME_MetaData.getPixelsSizeX(0).getValue(); % image width, pixels
                    StackSizeY = OME_MetaData.getPixelsSizeY(0).getValue();
                    StackSizeT = OME_MetaData.getPixelsSizeT(0).getValue(); % image width, pixels
                    StackSizeZ = OME_MetaData.getPixelsSizeZ(0).getValue(); % image width, pixels
                    StackSizeC = OME_MetaData.getPixelsStackSizeC(0).getValue();
                    voxelSizeX = OME_MetaData.getPixelsPhysicalSizeX(0).getValue(); % in µm
                    %voxelSizeXdouble = voxelSizeX.doubleValue();  clear voxelSizeX                                % The numeric value represented by this object after conversion to type double
                    voxelSizeY = OME_MetaData.getPixelsPhysicalSizeY(0).getValue(); % in µm
                    %voxelSizeYdouble = voxelSizeY.doubleValue();  clear voxelSizeY                                % The numeric value represented by this object after conversion to type double
                    voxelSizeZ = OME_MetaData.getPixelsPhysicalSizeZ(0).getValue(); % in µm
                    %voxelSizeZdouble = voxelSizeZ.doubleValue();  clear voxelSizeZ                                % The numeric value represented by this object after conversion to type double
                    if ~PartialMetaData
                        PlaneSpacing=voxelSizeZ;
                        ScaleFactor=voxelSizeX; %um/px
                        ScalingX=voxelSizeX;
                        ScalingY=voxelSizeY;
                        ScalingZ=voxelSizeZ;
                        ScalingT=0;
                    end
                % 
                %     voxelSizeX = OME_MetaData.getPixelsPhysicalSizeX(0).value(); % in µm
                %     voxelSizeXdouble = voxelSizeX.doubleValue();  clear voxelSizeX                                % The numeric value represented by this object after conversion to type double
                %     voxelSizeY = OME_MetaData.getPixelsPhysicalSizeY(0).value(); % in µm
                %     voxelSizeYdouble = voxelSizeY.doubleValue();  clear voxelSizeY                                % The numeric value represented by this object after conversion to type double
                %     voxelSizeZ = OME_MetaData.getPixelsPhysicalSizeZ(0).value(); % in µm
                %     voxelSizeZdouble = voxelSizeZ.doubleValue();  clear voxelSizeZ                                % The numeric value represented by this object after conversion to type double
                %     PlaneSpacing=voxelSizeZdouble;
                %     ScaleFactor=voxelSizeXdouble; %um/px

                catch
                    warning on
                    warning('Problem with extracting metadata trying another option...')
                    disp('Importing .tif File to access metadata...')
                    %Load metadata from .tif file
                    %tif_MetaData=tiffinfo(FileName);
                    tif_Data = bfopen([LoadDir,FileName]);
                    clear OME_MetaData BasicFileData
                    OME_MetaData=tif_Data{1, 2};
                    %BasicFileData=OME_MetaData;
                    %OME_MetaData=loci.formats.Memoizer(bfGetReader(), 0);
                    %OME_MetaData = bfGetReader([LoadDir,FileName]);
                    %OME_MetaData = imreadBFmeta([LoadDir,FileName]);
                    entries = OME_MetaData.entrySet.toArray;
                    vals = OME_MetaData.values.toArray;
                    keys = OME_MetaData.keys;
                    %tif_Data=imreadBF(FileName,1,1,1);
                    NumEntries=OME_MetaData.keySet.size;
                    if iscell(tif_Data)
                        TempImage=tif_Data{1}{1};
                    else
                        TempImage=tif_Data;
                    end
                    %clear TempData
                    clear OME_MetaData_Extracted
                    for i=1:NumEntries
                        tempval=entries(i).toString;
                        OME_MetaData_Extracted(i).Text=tempval;
                        OME_MetaData_Extracted(i).Values=vals(i);          
                        if any(strfind(OME_MetaData_Extracted(i).Text,'SizeX'))
                            StackSizeX=str2num(OME_MetaData_Extracted(i).Values);
                            disp(OME_MetaData_Extracted(i).Text)
                        end
                        if any(strfind(OME_MetaData_Extracted(i).Text,'SizeY'))
                            StackSizeY=str2num(OME_MetaData_Extracted(i).Values);
                            disp(OME_MetaData_Extracted(i).Text)
                        end
                        if any(strfind(OME_MetaData_Extracted(i).Text,'SizeZ'))
                            StackSizeZ=str2num(OME_MetaData_Extracted(i).Values);
                            disp(OME_MetaData_Extracted(i).Text)
                        end
                        if any(strfind(OME_MetaData_Extracted(i).Text,'StackSizeC'))
                            StackSizeC=str2num(OME_MetaData_Extracted(i).Values);
                            disp(OME_MetaData_Extracted(i).Text)
                        end
                        if ~PartialMetaData
                            if any(strfind(OME_MetaData_Extracted(i).Text,'ScalingX'))
                                ScalingX=str2num(OME_MetaData_Extracted(i).Values);
                                disp(OME_MetaData_Extracted(i).Text)
                            end
                            if any(strfind(OME_MetaData_Extracted(i).Text,'ScalingY'))
                                ScalingY=str2num(OME_MetaData_Extracted(i).Values);
                                disp(OME_MetaData_Extracted(i).Text)
                            end
                            if any(strfind(OME_MetaData_Extracted(i).Text,'ScalingZ'))
                                ScalingZ=str2num(OME_MetaData_Extracted(i).Values);
                                disp(OME_MetaData_Extracted(i).Text)
                            end
                        end
                    end
        %             for i=1:NumEntries
        %                 disp(OME_MetaData_Extracted(i).Text)
        %             end
        
                    clear TempImage
                    clear Default
                    for c=1:StackSizeC
                        for i=1:NumEntries
                            if any(strfind(OME_MetaData_Extracted(i).Text,['Dye #',num2str(c)]))
                                disp(OME_MetaData_Extracted(i).Text)
                                Channel_Labels{c}=[];
                                Channel_Labels{c}=OME_MetaData_Extracted(i).Values;
                                if isempty(Channel_Labels{c})
                                    Channel_Labels{c}=['Channel ',num2str(c)];
                                end
                                %Channel_Colors{c}=[1,1,1];
                                Channel_Colors{c}='w';
                                Channel_Color_Codes{c}=ColorDefinitionsLookup(Channel_Colors{c});
                                if any(strfind(Channel_Labels{c},'405'))
                                    Channel_Colors{c}='m';
                                elseif any(strfind(Channel_Labels{c},'488'))
                                    Channel_Colors{c}='g';
                                elseif any(strfind(Channel_Labels{c},'Cy3'))
                                    Channel_Colors{c}='w';
                                elseif any(strfind(Channel_Labels{c},'568'))
                                    Channel_Colors{c}='c';
                                elseif any(strfind(Channel_Labels{c},'561'))
                                    Channel_Colors{c}='c';
                                elseif any(strfind(Channel_Labels{c},'647'))
                                    Channel_Colors{c}='r';
                                end
                                %Channel_Colors{c}=ColorDefinitionsLookup('m');
                                Channel_Color_Codes{c}=ColorDefinitionsLookup(Channel_Colors{c});

                            end            
                        end
                    end
                end
                if ~exist('ScalingX')
                    ScalingX=0;
                end
                if ~exist('ScalingY')
                    ScalingY=0;
                end
                if ~exist('ScalingZ')
                    ScalingZ=0;
                end
                if ~exist('ScalingT')
                    ScalingT=0;
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                TestFig=figure('name',FileID);
                TestFrames=5;
                set(gcf,'position',[0,100,1000,300])
                for i=1:TestFrames
                    subplot(1,TestFrames,i)
                    imagesc(imread([LoadDir,dc,FileName],i))
                    axis equal tight
                    title(['Image ',num2str(i)])
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                if ~TurboMode
                    VerifySettings=1;
                    while VerifySettings
                        disp('============================================')
                        disp('Checking Settings...')
                        prompt = {'StackSizeX','StackSizeY','StackSizeT','StackSizeZ','StackSizeC',...
                            'ScalingX (um/px)','ScalingY (um/px)','ScalingZ (um/slice)','ScalingT/InterFrameTime (s)'};
                        dlg_title = 'Basic Properties';
                        num_lines = 1;
                            def = { num2str(StackSizeX),...
                                    num2str(StackSizeY),...
                                    num2str(StackSizeT),...
                                    num2str(StackSizeZ),...
                                    num2str(StackSizeC),...
                                    num2str(ScalingX),...
                                    num2str(ScalingY),...
                                    num2str(ScalingZ),...
                                    num2str(ScalingT)};
                        answer = inputdlg(prompt,dlg_title,num_lines,def);
                        StackSizeX=str2num(answer{1});
                        StackSizeY=str2num(answer{2});
                        StackSizeT=str2num(answer{3});
                        StackSizeZ=str2num(answer{4});
                        StackSizeC=str2num(answer{5});
                        ScalingX=str2num(answer{6});
                        ScalingY=str2num(answer{7});
                        ScalingZ=str2num(answer{8});
                        ScalingT=str2num(answer{9});

                        if StackSizeT*StackSizeZ*StackSizeC<TotalImages
                            warning on
                            warning(['Something doesnt add up to ',num2str(TotalImages),' total images'])
                            warning(['StackSizeT ',num2str(StackSizeT)])
                            warning(['StackSizeZ ',num2str(StackSizeZ)])
                            warning(['StackSizeC ',num2str(StackSizeC)])
                            if ~TurboMode
                                ConfirmDataSize = questdlg({'Do you want to proceed with import as defined'},'Proceed with data size?','Proceed','Try again','Try again');
                                switch ConfirmDataSize
                                    case 'Proceed'
                                        VerifySettings=0;
                                end
                            else
                                warning('Trying to load data as defined...')
                                VerifySettings=0;
                            end

                        elseif StackSizeT*StackSizeZ*StackSizeC>TotalImages
                            warning on
                            warning(['There are too many frames allocated for ',num2str(TotalImages),' total images'])
                            warning(['StackSizeT ',num2str(StackSizeT)])
                            warning(['StackSizeZ ',num2str(StackSizeZ)])
                            warning(['StackSizeC ',num2str(StackSizeC)])

                        else
                            VerifySettings=0;
                        end

                    end
                    if ~PartialMetaData
                        StackOrder='YX';
                        if StackSizeC>1
                            StackOrder=[StackOrder,'C'];
                        end
                        if StackSizeZ>1
                            StackOrder=[StackOrder,'Z'];
                        end
                        if StackSizeT>1
                            StackOrder=[StackOrder,'T'];
                        end
                    end
                    prompt = {'StackOrder'};
                    dlg_title = 'StackOrder';
                    num_lines = 1;
                    def = {StackOrder};
                    answer = inputdlg(prompt,dlg_title,num_lines,def);
                    StackOrder=answer{1};

                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                if ScalingX~=ScalingY
                    ScaleFactor=mean([ScalingX,ScalingY]);
                else
                    ScaleFactor=ScalingX;
                end
                PlaneSpacing=ScalingZ;
                disp('============================================')
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                if ~exist('Default')
                    warning('Using Empty Channel Defaults...')
                    for c=1:StackSizeC
                        Channel_Labels{c}=[];
                        if isempty(Channel_Labels{c})
                            Channel_Labels{c}=['Channel ',num2str(c)];
                        end
                        %Channel_Colors{c}=[1,1,1];
                        Channel_Colors{c}='w';
                        Channel_Color_Codes{c}=ColorDefinitionsLookup(Channel_Colors{c});
                        Channel_Color_Codes{c}=ColorDefinitionsLookup(Channel_Colors{c});

                    end            
                end
                BasicFileData.FileName=FileName;
                BasicFileData.imfinf=imfinf(1);
                try
                    close(TestFig)
                catch
                end
            case 2
                error('LSM import not ready')
        %         %Load metadata from .lsm file
        %         fprintf('Loading .lsm MetaData...')
        %         [lsminf,scaninf,imfinf] = lsminfo([LoadDir,dc,FileName]);
        %         ImageStructure=tiffread([LoadDir,dc,FileName]);
        %         ScaleFactor=scaninf.SAMPLE_SPACING; %um/px
        %         BitDepth=scaninf.BITS_PER_SAMPLE;
        %         fprintf('Finished!\n')
        %         if iscell(BitDepth)
        %             BitDepth=BitDepth{1};
        %         end
        %         DataClass='double';
        %         if BitDepth==16
        %             DataClass='uint16';
        %         elseif BitDepth==8
        %             DataClass='uint8';
        %         end
        %         if any(TestImage(:)<0)
        %             warning('Negative values, converting to double')
        %             BitDepth=16;
        %             DataClass='double';
        %         end
        %         %FileInfoArray = LSMFileInformationGatherer(FileID);
        %         BasicFileData.FileName=FileName;
        %         BasicFileData.imfinf=imfinf;
        %         BasicFileData.lsminf=lsminf;
        %         BasicFileData.scaninf=scaninf;
        %         OME_MetaData=lsminf;
        %         StackSizeZ=length(ImageStructure);
        %         StackSizeC=lsminf.NUMBER_OF_CHANNELS;
        %         PlaneSpacing=lsminf.ScanInfo.PLANE_SPACING;
        %         StackSizeZ=StackSizeZ;
        %         StackSizeX = lsminf.ScanInfo.IMAGES_WIDTH; % image width, pixels
        %         StackSizeY = lsminf.ScanInfo.IMAGES_HEIGHT;
        %         voxelSizeX = lsminf.ScanInfo.SAMPLE_SPACING; % in µm
        %         %voxelSizeXdouble = voxelSizeX.doubleValue();  clear voxelSizeX                                % The numeric value represented by this object after conversion to type double
        %         voxelSizeY = lsminf.ScanInfo.SAMPLE_SPACING; % in µm
        %         %voxelSizeYdouble = voxelSizeY.doubleValue();  clear voxelSizeY                                % The numeric value represented by this object after conversion to type double
        %         voxelSizeZ = lsminf.ScanInfo.PLANE_SPACING; % in µm
        %         %voxelSizeZdouble = voxelSizeZ.doubleValue();  clear voxelSizeZ                                % The numeric value represented by this object after conversion to type double
        %         ScalingX=voxelSizeX;
        %         ScalingY=voxelSizeY;
        %         ScalingZ=voxelSizeZ;
        %         ScaleFactor=voxelSizeX; %um/px
        %         Objective=lsminf.ScanInfo.ENTRY_OBJECTIVE;
        %         for c=1:StackSizeC
        %             Additional_MetaData(c).Label=lsminf.ScanInfo.DYE_NAME{c};
        %             if length(lsminf.ScanInfo.WAVELENGTH)==StackSizeC
        %                 Additional_MetaData(c).LaserType=lsminf.ScanInfo.WAVELENGTH{c};
        %                 Additional_MetaData(c).LaserWavelength=lsminf.ScanInfo.WAVELENGTH{c};
        %                 Additional_MetaData(c).LaserPower=lsminf.ScanInfo.POWER{c};
        %             else
        %                 Additional_MetaData(c).LaserType='unknown';
        %                 Additional_MetaData(c).LaserWavelength='unknown';
        %                 Additional_MetaData(c).LaserPower='unknown';
        %             end
        %             Additional_MetaData(c).Detector=lsminf.ScanInfo.DETECTION_CHANNEL_NAME{c};
        %             Additional_MetaData(c).Wavelength_Start=lsminf.ScanInfo.SPI_WAVE_LENGTH_START{c};
        %             Additional_MetaData(c).Wavelength_End=lsminf.ScanInfo.SPI_WAVELENGTH_END{c};
        %             Additional_MetaData(c).FrameTime=lsminf.ScanInfo.SAMPLE_0TIME/1000;
        %             Additional_MetaData(c).PinholeDiameter=lsminf.ScanInfo.PINHOLE_DIAMETER{c};
        %             Additional_MetaData(c).Gain=lsminf.ScanInfo.DETECTOR_GAIN{c};
        %             Additional_MetaData(c).AmplifierGain=lsminf.ScanInfo.AMPLIFIER_GAIN{c};
        %             Additional_MetaData(c).DigitalGain=lsminf.ScanInfo.AMPLIFIER_OFFSET{c};
        %             Additional_MetaData(c).ZoomX=lsminf.ScanInfo.ZOOM_X;
        %             Additional_MetaData(c).ZoomY=lsminf.ScanInfo.ZOOM_X;
        %             Additional_MetaData(c).PixelTime=lsminf.ScanInfo.PIXEL_TIME{1};
        %             Additional_MetaData(c).PixelAveraging=lsminf.ScanInfo.SAMPLING_NUMBER{1};
        %             Additional_MetaData(c).TrackNum=0;
        %             for Track=1:length(lsminf.ScanInfo.TRACK_NAME)
        %                 if any(strcmp(lsminf.ScanInfo.TRACK_NAME{Track},Additional_MetaData(c).Label))
        %                     Additional_MetaData(c).TrackNum=Track;
        %                     Additional_MetaData(c).PixelTime=lsminf.ScanInfo.PIXEL_TIME{Track};
        %                     Additional_MetaData(c).PixelAveraging=lsminf.ScanInfo.SAMPLING_NUMBER{Track};
        %                 end
        %             end
        %         end
        %         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %         if ~TurboMode
        %             disp('============================================')
        %             disp('Checking Settings...')
        %             prompt = {'StackSizeX','StackSizeY','StackSizeT','StackSizeZ','StackSizeC',...
        %                 'ScalingX (um/px)','ScalingY (um/px)','ScalingT/InterFrameTime (s)','ScalingZ (um/slice)'};
        %             dlg_title = 'Basic Properties';
        %             num_lines = 1;
        %                 def = { num2str(StackSizeX),...
        %                         num2str(StackSizeY),...
        %                         num2str(StackSizeT),...
        %                         num2str(StackSizeZ),...
        %                         num2str(StackSizeC),...
        %                         num2str(ScalingX),...
        %                         num2str(ScalingY),...
        %                         num2str(ScalingT),...
        %                         num2str(ScalingZ)};
        %             answer = inputdlg(prompt,dlg_title,num_lines,def);
        %             StackSizeX=str2num(answer{1});
        %             StackSizeY=str2num(answer{2});
        %             StackSizeT=str2num(answer{3});
        %             StackSizeZ=str2num(answer{4});
        %             StackSizeC=str2num(answer{5});
        %             ScalingX=str2num(answer{6});
        %             ScalingY=str2num(answer{7});
        %             ScalingT=str2num(answer{8});
        %             ScalingZ=str2num(answer{9});
        %             StackOrder='YX';
        %             if StackSizeZ>1
        %                 StackOrder=[StackOrder,'Z'];
        %             end
        %             if StackSizeT>1
        %                 StackOrder=[StackOrder,'T'];
        %             end
        %             if StackSizeC>1
        %                 StackOrder=[StackOrder,'C'];
        %             end
        %             
        %             prompt = {'StackOrder'};
        %             dlg_title = 'StackOrder';
        %             num_lines = 1;
        %             def = {StackOrder};
        %             answer = inputdlg(prompt,dlg_title,num_lines,def);
        %             StackOrder=answer{1};
        %             
        %         end
        %         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %         if ScalingX~=ScalingY
        %             ScaleFactor=mean([ScalingX,ScalingY]);
        %         else
        %             ScaleFactor=ScalingX;
        %         end
        %         for c=1:StackSizeC
        %             Channel_Labels{c}=lsminf.ScanInfo.DYE_NAME{c};
        %             if isempty(Channel_Labels{c})
        %                 Channel_Labels{c}=['Channel ',num2str(c)];
        %             end
        %             %Channel_Colors{c}=[1,1,1];
        %             Channel_Colors{c}='w';
        %             Channel_Color_Codes{c}=ColorDefinitionsLookup(Channel_Colors{c});
        %             if StackSizeC>3
        %                 if any(strfind(Channel_Labels{c},'405'))any(strfind(Channel_Labels{c},'40'))
        %                     Channel_Colors{c}='m';
        %                 elseif any(strfind(Channel_Labels{c},'488'))||any(strfind(Channel_Labels{c},'48'))
        %                     Channel_Colors{c}='g';
        %                 elseif any(strfind(Channel_Labels{c},'Cy3'))||any(strfind(Channel_Labels{c},'Cy'))
        %                     Channel_Colors{c}='w';
        %                 elseif any(strfind(Channel_Labels{c},'568'))any(strfind(Channel_Labels{c},'56'))
        %                     Channel_Colors{c}='c';
        %                 elseif any(strfind(Channel_Labels{c},'561'))any(strfind(Channel_Labels{c},'56'))
        %                     Channel_Colors{c}='c';
        %                 elseif any(strfind(Channel_Labels{c},'647'))||any(strfind(Channel_Labels{c},'64'))
        %                     Channel_Colors{c}='r';
        %                 end
        %             else
        %                 if any(strfind(Channel_Labels{c},'405'))any(strfind(Channel_Labels{c},'40'))
        %                     Channel_Colors{c}='m';
        %                 elseif any(strfind(Channel_Labels{c},'488'))||any(strfind(Channel_Labels{c},'48'))
        %                     Channel_Colors{c}='g';
        %                 elseif any(strfind(Channel_Labels{c},'Cy3'))||any(strfind(Channel_Labels{c},'Cy'))
        %                     Channel_Colors{c}='w';
        %                 elseif any(strfind(Channel_Labels{c},'568'))any(strfind(Channel_Labels{c},'56'))
        %                     Channel_Colors{c}='c';
        %                 elseif any(strfind(Channel_Labels{c},'561'))any(strfind(Channel_Labels{c},'56'))
        %                     Channel_Colors{c}='c';
        %                 elseif any(strfind(Channel_Labels{c},'647'))||any(strfind(Channel_Labels{c},'64'))
        %                     Channel_Colors{c}='m';
        %                 end
        %             end
        %             %Channel_Colors{c}=ColorDefinitionsLookup('m');
        %             Channel_Color_Codes{c}=ColorDefinitionsLookup(Channel_Colors{c});
        % 
        %         end            
        %         fprintf('Finished!\n')
        %         disp('==========================================================');
        %         disp('==========================================================');
        %         disp('==========================================================');
        %         disp('==========================================================');
        %         for c=1:StackSizeC
        %             disp('==================================');
        %             disp(['Channel ',num2str(c),': ',Channel_Labels{c}])
        % %             disp(['Laser: ',Additional_MetaData(c).LaserType,' ',...
        % %                 num2str(Additional_MetaData(c).LaserWavelength),'nm @',...
        % %                 num2str(Additional_MetaData(c).LaserPower),'%'])
        %             disp(['Laser @',...
        %                 num2str(Additional_MetaData(c).LaserPower),'%'])
        %             disp(['Detector: ',Additional_MetaData(c).Detector,' ',...
        %                 num2str(Additional_MetaData(c).Wavelength_Start),'nm-',...
        %                 num2str(Additional_MetaData(c).Wavelength_End),'nm'])
        %             disp(['Pinhole size = ',num2str(Additional_MetaData(c).PinholeDiameter)])
        %             disp(['Gain = ',num2str(Additional_MetaData(c).Gain),' ',...
        %                 'Amp Gain = ',num2str(Additional_MetaData(c).AmplifierGain),' ',...
        %                 'Digital Gain = ',num2str(Additional_MetaData(c).DigitalGain)])
        %             disp(['Scanning: ZoomX = ',num2str(Additional_MetaData(c).ZoomX),'X',...
        %                 ' ZoomY = ',num2str(Additional_MetaData(c).ZoomY),'X']);
        %             disp(['Frame Time = ',num2str(Additional_MetaData(c).FrameTime),'s '])
        %             disp(['Pixel Dwell = ',num2str(Additional_MetaData(c).PixelTime),'us ',...
        %                 'Averaging: ',num2str(Additional_MetaData(c).PixelAveraging)])            
        %         end
        %         disp('==========================================================');
        %         disp('==========================================================');
        %         disp('==========================================================');
        %         disp('==========================================================');
            case 3
                disp('Importing .CZI File to access metadata...')
                %Load metadata from .czi file
                CZI_MetaData=czifinfo([LoadDir,dc,FileName]);
                OME_MetaData = GetOMEData(FileName);
                StackOrder=OME_MetaData.DimOrder;
                CZI_Data = bfopen([LoadDir,FileName]);
                clear CZI_MetaData_Parsed
                CZI_MetaData_Parsed=CZI_Data{1, 2};
                %BasicFileData=CZI_MetaData_Parsed;
                %CZI_MetaData_Parsed=loci.formats.Memoizer(bfGetReader(), 0);
                %CZI_MetaData_Parsed = bfGetReader([LoadDir,FileName]);
                %CZI_MetaData_Parsed = imreadBFmeta([LoadDir,FileName]);
                entries = CZI_MetaData_Parsed.entrySet.toArray;
                vals = CZI_MetaData_Parsed.values.toArray;
                keys = CZI_MetaData_Parsed.keys;
                %CZI_Data=imreadBF([LoadDir,dc,FileName],1,1,1);
                NumEntries=CZI_MetaData_Parsed.keySet.size;
                if iscell(CZI_Data)
                    TempImage=CZI_Data{1}{1};
                else
                    TempImage=CZI_Data;
                end
                %clear TempData
                clear CZI_MetaData_Parsed_Extracted
                % for i=1:NumEntries
                % disp(entries(i).toString)
                %                     
                % end
                % 
                % for i=1:NumEntries
                %     tempval=entries(i).toString;
                %     CZI_MetaData_Parsed_Extracted(i).Text=tempval;
                %     CZI_MetaData_Parsed_Extracted(i).Values=vals(i);
                %     if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,'Scaling'))
                %         disp(CZI_MetaData_Parsed_Extracted(i).Text)
                %     end
                % end

                for i=1:NumEntries
                    tempval=entries(i).toString;
                    CZI_MetaData_Parsed_Extracted(i).Text=tempval;
                    CZI_MetaData_Parsed_Extracted(i).Values=vals(i);

                    if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,'Objective|Manufacturer|Model'))
                        Objective=str2num(CZI_MetaData_Parsed_Extracted(i).Values);
                        disp(CZI_MetaData_Parsed_Extracted(i).Text)
                    end            
                    if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,'Image|SizeX'))
                        StackSizeX=str2num(CZI_MetaData_Parsed_Extracted(i).Values);
                        disp(CZI_MetaData_Parsed_Extracted(i).Text)
                    end
                    if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,'Image|SizeY'))
                        StackSizeY=str2num(CZI_MetaData_Parsed_Extracted(i).Values);
                        disp(CZI_MetaData_Parsed_Extracted(i).Text)
                    end
                    if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,'Image|SizeZ'))
                        StackSizeZ=str2num(CZI_MetaData_Parsed_Extracted(i).Values);
                        disp(CZI_MetaData_Parsed_Extracted(i).Text)
                    end
                    if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,'StackSizeC'))||any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,'Image|SizeC'))
                        StackSizeC=str2num(CZI_MetaData_Parsed_Extracted(i).Values);
                        disp(CZI_MetaData_Parsed_Extracted(i).Text)
                    end

                    if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,'Image|Channel|PixelType #1=Gray16'))
                        BitDepth=16;
                        disp(CZI_MetaData_Parsed_Extracted(i).Text)
                    end
                    if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,'Image|Channel|PixelType #1=Gray8'))
                        BitDepth=8;
                        disp(CZI_MetaData_Parsed_Extracted(i).Text)
                    end
                    if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,'Global Scaling|Distance|Value #1'))
                        ScalingX=str2num(CZI_MetaData_Parsed_Extracted(i).Values);
                        disp(CZI_MetaData_Parsed_Extracted(i).Text)
                    end
                    if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,'Global Scaling|Distance|Value #1'))
                        ScalingY=str2num(CZI_MetaData_Parsed_Extracted(i).Values);
                        disp(CZI_MetaData_Parsed_Extracted(i).Text)
                    end
                    if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,'Global Scaling|Distance|Value #3'))
                        ScalingZ=str2num(CZI_MetaData_Parsed_Extracted(i).Values);
                        disp(CZI_MetaData_Parsed_Extracted(i).Text)
                    end
                end

                % ScalingX=ScalingX*1e6
                % ScalingY=ScalingY*1e6
                % ScalingZ=ScalingZ*1e6

                TempChannels=[];
                for c=1:StackSizeC
                    for i=1:NumEntries
                        tempval=entries(i).toString;
                        CZI_MetaData_Parsed_Extracted(i).Text=tempval;
                        CZI_MetaData_Parsed_Extracted(i).Values=vals(i);
                        if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,['Image|Channel|Name #',num2str(c)]))
                            disp(CZI_MetaData_Parsed_Extracted(i).Text)
                        end
                    end
                end


                if strcmp(class(TempImage),'uint16')
                    BitDepth=16;
                elseif strcmp(class(TempImage),'uint8')
                    BitDepth=8;
                end
                DataClass='double';
                if BitDepth==16
                    DataClass='uint16';
                elseif BitDepth==8
                    DataClass='uint8';
                end
                DataClass='double';
                clear TempImage
                
                if ScalingX<1e-6
                    warning on
                    warning('Adjusting Scaling Values to um from meters')
                    ScalingX=ScalingX*1e6;
                    ScalingY=ScalingY*1e6;
                    ScalingZ=ScalingZ*1e6;
                end
                    
                if ~PartialMetaData
                    if ScalingX~=ScalingY
                        ScaleFactor=mean([ScalingX,ScalingY]);
                    else
                        ScaleFactor=ScalingX;
                    end
                    PlaneSpacing=ScalingZ;
                    ScalingX=ScaleFactor;
                    ScalingY=ScaleFactor;
                    ScalingZ=PlaneSpacing;
                end
                
                if OME_MetaData.SizeX~=StackSizeX
                    warning('adjusting X size')
                    StackSizeX=OME_MetaData.SizeX;
                end
                if OME_MetaData.SizeY~=StackSizeY
                    warning('adjusting Y size')
                    StackSizeY=OME_MetaData.SizeY;
                end
                if OME_MetaData.SizeZ~=StackSizeZ
                    warning('adjusting Z size')
                    StackSizeZ=OME_MetaData.SizeZ;
                end
                if OME_MetaData.SizeC~=StackSizeC
                    warning('adjusting C size')
                    StackSizeC=OME_MetaData.SizeC;
                end
                
                for c=1:StackSizeC
                    Channel_Labels{c}=['Channel ',num2str(c)];
                    for i=1:NumEntries
                        if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,['Image|Channel|Name #',num2str(c)]))||...
                                any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,['Dye #',num2str(c)]))||...
                                any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,['TrackSetup|Name #',num2str(c)]))
                            disp(CZI_MetaData_Parsed_Extracted(i).Text)
                            Channel_Labels{c}=[];
                            Channel_Labels{c}=CZI_MetaData_Parsed_Extracted(i).Values;
                            if isempty(Channel_Labels{c})
                                Channel_Labels{c}=['Channel ',num2str(c)];
                            end
                            %Channel_Colors{c}=[1,1,1];
                            Channel_Colors{c}='w';
                            Channel_Color_Codes{c}=[1,1,1];
                            %Channel_Color_Codes{c}=ColorDefinitionsLookup(Channel_Colors{c});
                            if any(strfind(Channel_Labels{c},'405'))
                                Channel_Colors{c}='m';
                                Channel_Color_Codes{c}=[1,0,1];
                            elseif any(strfind(Channel_Labels{c},'488'))
                                Channel_Colors{c}='g';
                                Channel_Color_Codes{c}=[0,1,0];
                            elseif any(strfind(Channel_Labels{c},'Cy3'))
                                Channel_Colors{c}='w';
                                Channel_Color_Codes{c}=[1,1,1];
                            elseif any(strfind(Channel_Labels{c},'555'))
                                Channel_Colors{c}='c';
                                Channel_Color_Codes{c}=[0,1,1];
                            elseif any(strfind(Channel_Labels{c},'568'))
                                Channel_Colors{c}='c';
                                Channel_Color_Codes{c}=[0,1,1];
                            elseif any(strfind(Channel_Labels{c},'561'))
                                Channel_Colors{c}='c';
                                Channel_Color_Codes{c}=[0,1,1];
                            elseif any(strfind(Channel_Labels{c},'647'))
                                Channel_Colors{c}='r';
                                Channel_Color_Codes{c}=[1,0,0];
                            end
                            %Channel_Colors{c}=ColorDefinitionsLookup('m');
                            %Channel_Color_Codes{c}=ColorDefinitionsLookup(Channel_Colors{c});

                        end            
                    end
                end

                
                if StackSizeT==1
                    StackOrder(strfind(StackOrder,'T'))=[];
                end
                if strcmp(StackOrder(1),'X')
                    Fixed=0;
                    warning on
                    warning('Flipping XY in Stack Order to Play Nice with Stack_Viewer')
                    switch StackOrder
                        case 'XYCZ'
                            StackOrder='YXCZ';
                            Fixed=1;
                        case 'XYZC'
                            StackOrder='YXZC';
                            Fixed=1;
                    end
                    if ~Fixed
                        error('Unknown StackOrder Default in CZI Import Here')
                    end
                end
                warning('The Meta Data in .czi file has wrong laser name and wavelenth though other laser settings OK...')

                fprintf('Collecting additional meta data from the .czi file')
                clear AdditionalMetaData
                for c=1:StackSizeC
                    fprintf('.')
                    Additional_MetaData(c).Label=Channel_Labels{c};
                    Additional_MetaData(c).LaserType=[];
                    Additional_MetaData(c).LaserWavelength=[];
                    Additional_MetaData(c).LaserPower=[];
                    Additional_MetaData(c).Detector=[];
                    Additional_MetaData(c).Wavelength_Start=[];
                    Additional_MetaData(c).Wavelength_End=[];
                    Additional_MetaData(c).FrameTime=[];
                    Additional_MetaData(c).PixelTime=[];
                    Additional_MetaData(c).PixelAveraging=[];
                    Additional_MetaData(c).PinholeDiameter=[];
                    Additional_MetaData(c).Gain=[];
                    Additional_MetaData(c).AmplifierGain=[];
                    Additional_MetaData(c).DigitalGain=[];
                    Additional_MetaData(c).ZoomX=[];
                    Additional_MetaData(c).ZoomY=[];

                    for i=1:NumEntries
                        if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,['Laser|LaserName #',num2str(c)]))
                            Additional_MetaData(c).LaserType=(CZI_MetaData_Parsed_Extracted(i).Values);
                        end            
                        if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,['Laser|Wavelength #',num2str(c)]))
                            Additional_MetaData(c).LaserWavelength=str2num(CZI_MetaData_Parsed_Extracted(i).Values);
                        end            
                        if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,['|Power #',num2str(c)]))
                            Additional_MetaData(c).LaserPower=round(str2num(CZI_MetaData_Parsed_Extracted(i).Values)*10)/10;
                        end            
                        if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,['DetectorWavelengthRange|WavelengthStart #',num2str(c)]))
                            Additional_MetaData(c).Wavelength_Start=round((str2num(CZI_MetaData_Parsed_Extracted(i).Values)*1e9)*10)/10;
                        end            
                        if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,['DetectorWavelengthRange|WavelengthEnd #',num2str(c)]))
                            Additional_MetaData(c).Wavelength_End=round((str2num(CZI_MetaData_Parsed_Extracted(i).Values)*1e9)*10)/10;
                        end            
                        if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,['ImageChannelName #',num2str(c)]))
                            Additional_MetaData(c).Detector=(CZI_MetaData_Parsed_Extracted(i).Values);
                        end            
                        if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,['FrameTime #',num2str(c)]))
                            Additional_MetaData(c).FrameTime=str2num(CZI_MetaData_Parsed_Extracted(i).Values);
                        end            
                        if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,['PixelTime #',num2str(c)]))
                            Additional_MetaData(c).PixelTime=round((str2num(CZI_MetaData_Parsed_Extracted(i).Values)*1e6)*100)/100;
                        end            
                        if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,['PinholeDiameter #',num2str(c)]))
                            Additional_MetaData(c).PinholeDiameter=round((str2num(CZI_MetaData_Parsed_Extracted(i).Values)*1e6)*100)/100;
                        end            
                        if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,['Image|Channel|Gain #',num2str(c)]))
                            Additional_MetaData(c).Gain=str2num(CZI_MetaData_Parsed_Extracted(i).Values);
                        end            
                        if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,['|AmplifierGain #',num2str(c)]))
                            Additional_MetaData(c).AmplifierGain=str2num(CZI_MetaData_Parsed_Extracted(i).Values);
                        end            
                        if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,['|DigitalGain #',num2str(c)]))
                            Additional_MetaData(c).DigitalGain=str2num(CZI_MetaData_Parsed_Extracted(i).Values);
                        end            
                        if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,['|ZoomX #',num2str(c)]))
                            Additional_MetaData(c).ZoomX=str2num(CZI_MetaData_Parsed_Extracted(i).Values);
                        end            
                        if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,['|ZoomY #',num2str(c)]))
                            Additional_MetaData(c).ZoomY=str2num(CZI_MetaData_Parsed_Extracted(i).Values);
                        end            
                        if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,['|Averaging #',num2str(c)]))
                            Additional_MetaData(c).PixelAveraging=str2num(CZI_MetaData_Parsed_Extracted(i).Values);
                        end            
                    end            
                end
                fprintf('Finished!\n')
        %         for i=1:NumEntries
        %             if any(strfind(CZI_MetaData_Parsed_Extracted(i).Text,['|AmplifierGain ']))
        %                 disp(CZI_MetaData_Parsed_Extracted(i).Text)
        %             end            
        %         end
                disp('==========================================================');
                disp('==========================================================');
                warning('The Meta Data in .czi file MAY HAVE the wrong laser name and wavelenth though other laser settings OK...')
                disp('==========================================================');
                disp('==========================================================');
                for c=1:StackSizeC
                    disp('==================================');
                    disp(['Channel ',num2str(c),': ',Additional_MetaData(c).Label])
        %             disp(['Laser: ',Additional_MetaData(c).LaserType,' ',...
        %                 num2str(Additional_MetaData(c).LaserWavelength),'nm @',...
        %                 num2str(Additional_MetaData(c).LaserPower),'%'])
                    disp(['Laser @',...
                        num2str(Additional_MetaData(c).LaserPower),'%'])
                    disp(['Detector: ',Additional_MetaData(c).Detector,' ',...
                        num2str(Additional_MetaData(c).Wavelength_Start),'nm-',...
                        num2str(Additional_MetaData(c).Wavelength_End),'nm'])
                    disp(['Pinhole size = ',num2str(Additional_MetaData(c).PinholeDiameter)])
                    disp(['Gain = ',num2str(Additional_MetaData(c).Gain),' ',...
                        'Amp Gain = ',num2str(Additional_MetaData(c).AmplifierGain),' ',...
                        'Digital Gain = ',num2str(Additional_MetaData(c).DigitalGain)])
                    disp(['Scanning: ZoomX = ',num2str(Additional_MetaData(c).ZoomX),'X',...
                        ' ZoomY = ',num2str(Additional_MetaData(c).ZoomY),'X']);
                    disp(['Frame Time = ',num2str(Additional_MetaData(c).FrameTime),'s '])
                    disp(['Pixel Dwell = ',num2str(Additional_MetaData(c).PixelTime),'us ',...
                        'Averaging: ',num2str(Additional_MetaData(c).PixelAveraging)])            
                end
                disp('==========================================================');
                disp('==========================================================');
                warning('The Meta Data in .czi file MAY HAVE the wrong laser name and wavelenth though other laser settings OK...')
                disp('==========================================================');
                disp('==========================================================');
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                if ~TurboMode
                    disp('============================================')
                    disp('Checking Settings...')
                    prompt = {'StackSizeX','StackSizeY','StackSizeT','StackSizeZ','StackSizeC','ScalingX (um/px)','ScalingY (um/px)','ScalingZ (um/slice)'};
                    dlg_title = 'Basic Properties';
                    num_lines = 1;
                    def = { num2str(StackSizeX),...
                            num2str(StackSizeY),...
                            num2str(StackSizeT),...
                            num2str(StackSizeZ),...
                            num2str(StackSizeC),...
                            num2str(ScalingX),...
                            num2str(ScalingY),...
                            num2str(ScalingZ)};
                    answer = inputdlg(prompt,dlg_title,num_lines,def);
                    StackSizeX=str2num(answer{1});
                    StackSizeY=str2num(answer{2});
                    StackSizeT=str2num(answer{3});
                    StackSizeZ=str2num(answer{4});
                    StackSizeC=str2num(answer{5});
                    ScalingX=str2num(answer{6});
                    ScalingY=str2num(answer{7});
                    ScalingZ=str2num(answer{8});
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    disp('==========================================================');
    disp('==========================================================');
    disp('==========================================================');
    disp('==========================================================');
    disp(['Objective: ',Objective])
    disp(['StackSizeX = ',num2str(StackSizeX)])
    disp(['StackSizeY = ',num2str(StackSizeY)])
    disp(['StackSizeZ = ',num2str(StackSizeZ)])
    disp(['StackSizeC = ',num2str(StackSizeC)])
    disp(['StackSizeT = ',num2str(StackSizeT)])
    disp(['StackOrder = ',num2str(StackOrder)])
    disp(['ScalingX = ',num2str(ScalingX)])
    disp(['ScalingY = ',num2str(ScalingY)])
    disp(['ScalingZ = ',num2str(ScalingZ)])
    disp(['ScalingT = ',num2str(ScalingT)])
    disp('=========================');
    if exist('Additional_MetaData')
        if ~isempty(Additional_MetaData)
            for c=1:StackSizeC
                disp(['Channel ',num2str(c),' ',Additional_MetaData(c).Label])
            end
        end
    end
    disp('==========================================================');
    disp('==========================================================');
    disp('==========================================================');
    disp('==========================================================');
    if isempty(ChannelSelection)
        ChannelList=[1:StackSizeC];
    else
        ChannelList=ChannelSelection;
    end
    if ~TurboMode
        if length(ChannelList)>1
            if length(ChannelList)>1
                ChannelListString=[mat2str(ChannelList)];
            elseif length(ChannelList)==1
                ChannelListString=['[',mat2str(ChannelList),']'];
            else
                ChannelListString=['[]'];
            end
            prompt = {'Channels: '};
            dlg_title = ['What channels to include'];
            num_lines = 1;
            def = {ChannelListString};
            answer = inputdlg(prompt,dlg_title,num_lines,def);
            ChannelList=ConvertString2Array(answer{1});
            clear answer;
        end
    end
    MetaData.OME_MetaData=OME_MetaData;
    MetaData.BitDepth=BitDepth;
    MetaData.Objective=Objective;
    MetaData.StackSizeX=StackSizeX;
    MetaData.StackSizeY=StackSizeY;
    MetaData.StackSizeZ=StackSizeZ;
    MetaData.StackSizeT=StackSizeT;
    MetaData.StackSizeC=StackSizeC;
    MetaData.ChannelList=ChannelList;
    MetaData.PlaneSpacing=PlaneSpacing;
    MetaData.ScaleFactor=ScaleFactor;
    MetaData.ScalingX=ScalingX;
    MetaData.ScalingY=ScalingY;
    MetaData.ScalingT=ScalingT;
    MetaData.ScalingZ=ScalingZ;
    MetaData.StackOrder=StackOrder;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Load Data
    disp('==============================================')
    disp('==============================================')
    disp('==============================================')
    disp('Loading Data...')
    warning off
    switch FileType
        case 1
            f = waitbar(0,'Loading TIF Data Please wait...');
            switch StackOrder
                case 'YXZT'
                    ImageArray=zeros(StackSizeY,StackSizeX,StackSizeZ,StackSizeT,DataClass);
                    slice=1;
                    frame=1;
                    TotalNumImages=StackSizeZ*StackSizeT;
                    for i=1:TotalNumImages
                        TempImage=imread([LoadDir,dc,FileName],i);
                        switch DataClass
                            case 'double'
                                ImageArray(:,:,slice,frame)=double(TempImage);
                            case 'single'
                                ImageArray(:,:,slice,frame)=single(TempImage);
                            case 'uint16'
                                ImageArray(:,:,slice,frame)=uint16(TempImage);
                            case 'uint8'
                                ImageArray(:,:,slice,frame)=uint8(TempImage);
                        end
                        clear TempImage
                        if StackSizeZ==slice
                            slice=1;
                            frame=frame+1;
                        else
                            slice=slice+1;
                        end
                        waitbar(i/TotalNumImages,f,'Loading TIF Data Please wait...');
                    end
                case 'YXZC'
                    ImageArray=zeros(StackSizeY,StackSizeX,StackSizeZ,StackSizeC,DataClass);
                    slice=1;
                    channel=1;
                    TotalNumImages=StackSizeZ*StackSizeC;
                    for i=1:TotalNumImages
                        TempImage=imread([LoadDir,dc,FileName],i);
                        switch DataClass
                            case 'double'
                                ImageArray(:,:,slice,channel)=double(TempImage);
                            case 'single'
                                ImageArray(:,:,slice,channel)=single(TempImage);
                            case 'uint16'
                                ImageArray(:,:,slice,channel)=uint16(TempImage);
                            case 'uint8'
                                ImageArray(:,:,slice,channel)=uint8(TempImage);
                        end
                        clear TempImage
                        if StackSizeZ==slice
                            slice=1;
                            channel=channel+1;
                        else
                            slice=slice+1;
                        end
                        waitbar(i/TotalNumImages,f,'Loading TIF Data Please wait...');
                    end
                case 'YXCZ'
                    ImageArray=zeros(StackSizeY,StackSizeX,StackSizeC,StackSizeZ,DataClass);
                    slice=1;
                    channel=1;
                    TotalNumImages=StackSizeZ*StackSizeC;
                    for i=1:TotalNumImages
                        TempImage=imread([LoadDir,dc,FileName],i);
                        switch DataClass
                            case 'double'
                                ImageArray(:,:,channel,slice)=double(TempImage);
                            case 'single'
                                ImageArray(:,:,channel,slice)=single(TempImage);
                            case 'uint16'
                                ImageArray(:,:,channel,slice)=uint16(TempImage);
                            case 'uint8'
                                ImageArray(:,:,channel,slice)=uint8(TempImage);
                        end
                        clear TempImage
                        if StackSizeC==channel
                            channel=1;
                            slice=slice+1;
                        else
                            channel=channel+1;
                        end
                        waitbar(i/TotalNumImages,f,'Loading TIF Data Please wait...');
                    end
            end
            waitbar(1,f,['Finished!']);
            close(f)
            if ~exist('ImageArray')
                error('Missing StackOrder Preset!')
            end
        case 2
            f = waitbar(0,'Loading LSM Data Please wait...');
            for slice=1:StackSizeZ
                waitbar(slice/StackSizeZ,f,'Loading LSM Data Please wait...');
                ChannelCount=0;
                for i=1:length(ChannelList)
                    ChannelCount=ChannelCount+1;
                    CurrentChannel=ChannelList(ChannelCount);
                    if isfield(scaninf,'COLLIMATOR1_NAME')
                        MicroscopeName=scaninf.COLLIMATOR1_NAME;
            %             if length(MicroscopeName)>1
            %                 MicroscopeName=scaninf.COLLIMATOR1_NAME{1};
            %             end
                        if strcmp(MicroscopeName,'LIVE/RG')
                            %disp('NOTE: Image Data came from 5-LIVE');
                            if size(ImageStructure(slice).data{1,CurrentChannel},1)>1
                                temp=ImageStructure(slice).data{1,CurrentChannel};
                                Channel(ChannelCount).RawData(:,:,slice)=temp;
                                clear temp
                            else
                                Channel(ChannelCount).RawData(:,:,slice)=ImageStructure(slice).data;
                            end

                        else
                            Channel(ChannelCount).RawData(:,:,slice)=ImageStructure(slice).data{1,CurrentChannel};
                        end
                    else
                        if iscell(ImageStructure(slice).data)
                            Channel(ChannelCount).RawData(:,:,slice)=ImageStructure(slice).data{1,CurrentChannel};
                        else
                            Channel(ChannelCount).RawData(:,:,slice)=ImageStructure(slice).data;
                        end
                    end
                end
            end
            waitbar(1,f,['Finished!']);
            close(f)
        case 3
            %if ~exist('CZI_Data')
    %         for slice=1:StackSizeZ
    %             ChannelCount=0;
    %             for i=ChannelList(1):ChannelList(StackSizeC)
    %                 ChannelCount=ChannelCount+1;
    %                 if BitDepth==16
    %                     Channel(ChannelCount).RawData(:,:,slice)=(imreadBF([LoadDir,dc,FileName],slice,1,ChannelCount));
    %                 elseif BitDepth==8
    %                     Channel(ChannelCount).RawData(:,:,slice)=(imreadBF([LoadDir,dc,FileName],slice,1,ChannelCount));
    %                 end
    %             end
    %         end
            %else

            %end
%             [ImageArray,MetaData.MoreMetaData]=CZI_Importer([LoadDir,dc,FileName]);
%             for slice=1:StackSizeZ
%                 waitbar(slice/StackSizeZ,f,'Loading CZI Data Please wait...');
%                 ChannelCount=0;
%                 for i=1:length(ChannelList)
%                     ChannelCount=ChannelCount+1;
%                     CurrentChannel=ChannelList(ChannelCount);
%                     if BitDepth==16
%                         Channel(ChannelCount).RawData(:,:,slice)=(TempImageArray(:,:,slice,CurrentChannel));
%                     elseif BitDepth==8
%                         Channel(ChannelCount).RawData(:,:,slice)=(TempImageArray(:,:,slice,CurrentChannel));
%                     end
%                 end
%             end
%             clear TempImageArray
    switch StackOrder
        case 'YXCZ'
            if BitDepth==16
                ImageArray=zeros(StackSizeY,StackSizeX,StackSizeC,StackSizeZ,'uint16');
            elseif BitDepth==8
                ImageArray=zeros(StackSizeY,StackSizeX,StackSizeC,StackSizeZ,'uint8');
            end
            t=1;
            fprintf('Loading Data...')
            warning off
            f = waitbar(0,'Loading CZI Data Please wait...');
            ImageCount=StackSizeZ*StackSizeC;
            Count=0;
            for z=1:StackSizeZ
                for c=1:StackSizeC
                    warning off
                    TempImage=imreadBF(FileName,z,t,c);
                    if any(TempImage(:)<0)
                        warning on
                        warning('Negative values present..trying to fix...')
                        warning off
                        TempMask=TempImage;
                        TempMask(TempMask>=0)=0;
                        TempMask(TempMask<0)=1;
                        TempMask=logical(TempMask);
                        TempImage(TempMask)=abs(TempImage(TempMask)+2^BitDepth);
                    end
                    ImageArray(:,:,c,z)=TempImage;
                    Count=Count+1;
                    waitbar(Count/ImageCount,f,'Loading CZI Data Please wait...');
                end
            end
            fprintf('Finished!\n')
            waitbar(1,f,['Finished!']);
            close(f)
        case 'YXZC'
            if BitDepth==16
                ImageArray=zeros(StackSizeY,StackSizeX,StackSizeZ,StackSizeC,'uint16');
            elseif BitDepth==8
                ImageArray=zeros(StackSizeY,StackSizeX,StackSizeZ,StackSizeC,'uint8');
            end
            t=1;
            fprintf('Loading Data...')
            warning off
            f = waitbar(0,'Loading CZI Data Please wait...');
            ImageCount=StackSizeZ*StackSizeC;
            Count=0;
            for z=1:StackSizeZ
                for c=1:StackSizeC
                    warning off
                    TempImage=imreadBF(FileName,z,t,c);
                    if any(TempImage(:)<0)
                        warning on
                        warning('Negative values present..trying to fix...')
                        warning off
                        TempMask=TempImage;
                        TempMask(TempMask>=0)=0;
                        TempMask(TempMask<0)=1;
                        TempMask=logical(TempMask);
                        TempImage(TempMask)=abs(TempImage(TempMask)+2^BitDepth);
                    end
                    ImageArray(:,:,z,c)=TempImage;
                    Count=Count+1;
                    waitbar(Count/ImageCount,f,'Loading CZI Data Please wait...');
                end
            end
            fprintf('Finished!\n')
            waitbar(1,f,['Finished!']);
            close(f)

    end

        
    end
    disp('==============================================')
    disp('==============================================')
    disp('==============================================')
    warning on
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if ~TurboMode
        DataRegionChoice = questdlg({'Do you want to add a Data Region Mask';'NOTE: this is only currently useful if you are loading tile data'},...
            'Data Region Mask?','Mask','Skip','Skip');
        switch DataRegionChoice
            case 'Mask'
                fprintf('Making DataRegion Mask...')
                switch StackOrder
                    case 'YXT'
                        YDim=1;
                        XDim=2;
                        ZDim=0;
                        CDim=0;
                        TDim=3;
                        error('Not Ready yet!')
                    case 'YXZ'
                        YDim=1;
                        XDim=2;
                        ZDim=3;
                        CDim=0;
                        TDim=0;
                        error('Not Ready yet!')
                    case 'YXC'
                        YDim=1;
                        XDim=2;
                        ZDim=0;
                        CDim=3;
                        TDim=0;
                        error('Not Ready yet!')
                    case 'YXZT'
                        YDim=1;
                        XDim=2;
                        ZDim=3;
                        CDim=0;
                        TDim=4;
                        error('Not Ready yet!')
                    case 'YXTZ'
                        YDim=1;
                        XDim=2;
                        ZDim=4;
                        CDim=0;
                        TDim=3;
                        error('Not Ready yet!')
                    case 'YXTC'
                        YDim=1;
                        XDim=2;
                        ZDim=0;
                        CDim=4;
                        TDim=3;
                        error('Not Ready yet!')
                        DataRegion=zeros(size(ImageArray,YDim),size(ImageArray,XDim),size(ImageArray,TDim),size(ImageArray,CDim),'uint16');
                        for t=1:size(ImageArray,TDim)
                            TempStack=zeros(size(ImageArray,YDim),size(ImageArray,XDim),size(ImageArray,CDim),1,'uint16');
                            for c=1:size(ImageArray,CDim)
                                TempStack=TempStack+ImageArray(:,:,t,c);
                            end
                            for c=1:size(ImageArray,CDim)
                                DataRegion(:,:,t,c)=TempStack(:,:,1,c)+DataRegion(:,:,t,c);
                            end
                            clear TempStack
                        end
                        DataRegion(DataRegion<=0)=0;
                        DataRegion(DataRegion>0)=1;
                        DataRegion=logical(DataRegion);
                        for c=1:size(ImageArray,CDim)
                            for z=1:size(ImageArray,TDim)
                                DataRegion(:,:,z,c)=imfill(DataRegion(:,:,z,c),'holes');
                            end
                        end
                        fprintf('Finished!\n')
                    case 'YXCT'
                        YDim=1;
                        XDim=2;
                        TDim=0;
                        CDim=3;
                        TDim=4;
                        error('Not Ready yet!')
                        DataRegion=zeros(size(ImageArray,YDim),size(ImageArray,XDim),size(ImageArray,CDim),size(ImageArray,TDim),'uint16');
                        for t=1:size(ImageArray,TDim)
                            TempStack=zeros(size(ImageArray,YDim),size(ImageArray,XDim),size(ImageArray,CDim),1,'uint16');
                            for c=1:size(ImageArray,CDim)
                                TempStack=TempStack+ImageArray(:,:,c,t);
                            end
                            for c=1:size(ImageArray,CDim)
                                DataRegion(:,:,c,t)=TempStack(:,:,c,1)+DataRegion(:,:,c,t);
                            end
                            clear TempStack
                        end
                        DataRegion(DataRegion<=0)=0;
                        DataRegion(DataRegion>0)=1;
                        DataRegion=logical(DataRegion);
                        for c=1:size(ImageArray,CDim)
                            for z=1:size(ImageArray,TDim)
                                DataRegion(:,:,c,z)=imfill(DataRegion(:,:,c,z),'holes');
                            end
                        end
                    case 'YXZC'
                        YDim=1;
                        XDim=2;
                        ZDim=3;
                        CDim=4;
                        TDim=0;
                        DataRegion=zeros(size(ImageArray,YDim),size(ImageArray,XDim),size(ImageArray,ZDim),size(ImageArray,CDim),'uint16');
                        for z=1:size(ImageArray,ZDim)
                            TempStack=zeros(size(ImageArray,YDim),size(ImageArray,XDim),size(ImageArray,CDim),1,'uint16');
                            for c=1:size(ImageArray,CDim)
                                TempStack=TempStack+ImageArray(:,:,z,c);
                            end
                            for c=1:size(ImageArray,CDim)
                                DataRegion(:,:,z,c)=TempStack(:,:,1,c)+DataRegion(:,:,z,c);
                            end
                            clear TempStack
                        end
                        DataRegion(DataRegion<=0)=0;
                        DataRegion(DataRegion>0)=1;
                        DataRegion=logical(DataRegion);
                        for c=1:size(ImageArray,CDim)
                            for z=1:size(ImageArray,ZDim)
                                DataRegion(:,:,z,c)=imfill(DataRegion(:,:,z,c),'holes');
                            end
                        end
                    case 'YXCZ'
                        YDim=1;
                        XDim=2;
                        ZDim=4;
                        CDim=3;
                        TDim=0;
                        DataRegion=zeros(size(ImageArray,YDim),size(ImageArray,XDim),size(ImageArray,CDim),size(ImageArray,ZDim),'uint16');
                        for z=1:size(ImageArray,ZDim)
                            TempStack=zeros(size(ImageArray,YDim),size(ImageArray,XDim),size(ImageArray,CDim),1,'uint16');
                            for c=1:size(ImageArray,CDim)
                                TempStack=TempStack+ImageArray(:,:,c,z);
                            end
                            for c=1:size(ImageArray,CDim)
                                DataRegion(:,:,c,z)=TempStack(:,:,c,1)+DataRegion(:,:,c,z);
                            end
                            clear TempStack
                        end
                        DataRegion(DataRegion<=0)=0;
                        DataRegion(DataRegion>0)=1;
                        DataRegion=logical(DataRegion);
                        for c=1:size(ImageArray,CDim)
                            for z=1:size(ImageArray,ZDim)
                                DataRegion(:,:,c,z)=imfill(DataRegion(:,:,c,z),'holes');
                            end
                        end
                    case 'YXZTC'
                        YDim=1;
                        XDim=2;
                        ZDim=3;
                        CDim=5;
                        TDim=4;
                        error('Not Ready yet!')
                        DataRegion=zeros(size(ImageArray,YDim),size(ImageArray,XDim),size(ImageArray,ZDim),size(ImageArray,TDim),size(ImageArray,CDim),'uint16');
                        for z=1:size(ImageArray,ZDim)
                            TempStack=zeros(size(ImageArray,YDim),size(ImageArray,XDim),1,size(ImageArray,TDim),size(ImageArray,CDim),'uint16');
                            for t=1:size(ImageArray,TDim)
                                for c=1:size(ImageArray,CDim)
                                    TempStack=TempStack+ImageArray(:,:,z,t,c);
                                end
                            end
                            for t=1:size(ImageArray,TDim)
                                for c=1:size(ImageArray,CDim)
                                    DataRegion(:,:,z,t,c)=TempStack(:,:,1,t,c)+DataRegion(:,:,z,t,c);
                                end
                            end
                            clear TempStack
                        end
                        DataRegion(DataRegion<=0)=0;
                        DataRegion(DataRegion>0)=1;
                        DataRegion=logical(DataRegion);
                        for c=1:size(ImageArray,CDim)
                            for t=1:size(ImageArray,TDim)
                                for z=1:size(ImageArray,ZDim)
                                    DataRegion(:,:,z,t,c)=imfill(DataRegion(:,:,z,t,c),'holes');
                                end
                            end
                        end
                    case 'YXTZC'
                        YDim=1;
                        XDim=2;
                        ZDim=4;
                        CDim=5;
                        TDim=3;
                        error('Not Ready yet!')

                    case 'YX[RGB]T'
                        YDim=1;
                        XDim=2;
                        ZDim=0;
                        CDim=0;
                        TDim=4;
                        error('Not Ready yet!')

                    case 'YXT[RGB]'
                        YDim=1;
                        XDim=2;
                        ZDim=0;
                        CDim=0;
                        TDim=3;
                        error('Not Ready yet!')

                end
                fprintf('Finished!\n')
        end
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if Save2Scratch
        if ~TurboMode
            DeleteChoice = questdlg({'Do you want to delete';FileName;['from: ',ScratchDir]},...
                'Delete Scratch Dir Data?','Delete','Skip','Delete');
        else
            DeleteChoice='Delete';
        end
        switch DeleteChoice
            case 'Delete'
                try
                    recyclestate = recycle;
                    switch recyclestate
                        case 'off'
                            recycle('on');
                            delete([ScratchDir,dc,FileName])
                            recycle('off');
                        case 'on'
                            delete([ScratchDir,dc,FileName])
                    end
                catch
                    warning('Problem Deleting File...')
                end
        end
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function ColorCode=ColorDefinitionsLookup(ColorAbbreviation)
            %ColorDefinitionsLookup('m')
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
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

end