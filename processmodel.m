function processmodel(pm)
    % Defines the project's processmodel

    arguments
        pm padv.ProcessModel
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% Include/Exclude Tasks in processmodel
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    includeModelStandardsTask = true;
    includeDesignErrorDetectionTask = true;
    includeModelComparisonTask = true;
    includeSDDTask = true;
    includeSimulinkWebViewTask = true;
    includeTestsPerTestCaseTask = true;
    includeMergeTestResultsTask = true;
    includeGenerateCodeTask = true;
    includeAnalyzeModelCode = true && ~padv.internal.isMACA64 && exist('polyspaceroot','file');
    includeProveCodeQuality = true && ~padv.internal.isMACA64 && (~isempty(ver('pscodeprover')) || ~isempty(ver('pscodeproverserver')));
    includeCodeInspection = true;

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% Define Shared Path Variables
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Set default root directory for task results
    pm.DefaultOutputDirectory = fullfile('$PROJECTROOT$', '04_Results');
	defaultTestResultPath = fullfile('$DEFAULTOUTPUTDIR$','test_results');

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% Register Tasks
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %% Check modeling standards
    % Tools required: Model Advisor
    if includeModelStandardsTask
        maTask = pm.addTask(padv.builtin.task.RunModelStandards());
        maTask.addInputQueries(padv.builtin.query.FindFileWithAddress( ...
            Type='ma_config_file', Path=fullfile('tools','sampleChecks.json')));
        % Change Report path
        maTask.ReportPath = fullfile(...
            '$DEFAULTOUTPUTDIR$','$ITERATIONARTIFACT$','model_standards_results');
    end

    %% Detect design errors
    % Tools required: Simulink Design Verifier
    if includeDesignErrorDetectionTask
        dedTask = pm.addTask(padv.builtin.task.DetectDesignErrors());
    end

    %% Generate Model Comparison
    if includeModelComparisonTask
        mdlCompTask = pm.addTask(padv.builtin.task.GenerateModelComparison());
    end

    %% Generate SDD report (System Design Description)
    %  Tools required: Simulink Report Generator
    if includeSDDTask
        sddTask = pm.addTask(padv.builtin.task.GenerateSDDReport());
    end

    %% Generate Simulink web view
    % Tools required: Simulink Report Generator
    if includeSimulinkWebViewTask
        slwebTask = pm.addTask(padv.builtin.task.GenerateSimulinkWebView());
    end

    %% Run tests per test case
    % Tools required: Simulink Test
    if includeTestsPerTestCaseTask
        milTask = pm.addTask(padv.builtin.task.RunTestsPerTestCase());
        milTask.OutputDirectory = defaultTestResultPath;
    end

    %% Merge test results
    % Tools required: Simulink Test (and optionally Simulink Coverage)
    if includeTestsPerTestCaseTask && includeMergeTestResultsTask
        mergeTestTask = pm.addTask(padv.builtin.task.MergeTestResults());
        mergeTestTask.ReportPath = defaultTestResultPath;
        mergeTestTask.CovReportPath = defaultTestResultPath;
    end

    %% Generate Code
    % Tools required: Embedded Coder
    % By default, we generate code for all models in the project;
    if includeGenerateCodeTask
        codegenTask = pm.addTask(padv.builtin.task.GenerateCode());
        codegenTask.UpdateThisModelReferenceTarget = 'IfOutOfDate';
    end

    %% Check coding standards 
    % Tools required: Polyspace Bug Finder
    if includeGenerateCodeTask && includeAnalyzeModelCode
        psbfTask = pm.addTask(padv.builtin.task.AnalyzeModelCode());
        psbfTask.addInputQueries(padv.builtin.query.FindFileWithAddress( ...
            Type='ps_prj_file',Path=fullfile('tools','CodingRulesOnly_config.psprj')));
        psbfTask.ResultDir = string(fullfile('$DEFAULTOUTPUTDIR$', ...
            '$ITERATIONARTIFACT$','coding_standards'));
        psbfTask.Reports = "CodingStandards";
        psbfTask.ReportPath = string(fullfile('$DEFAULTOUTPUTDIR$', ...
            '$ITERATIONARTIFACT$','coding_standards'));
        psbfTask.ReportNames = "$ITERATIONARTIFACT$_CodingStandards";
        psbfTask.ReportFormat = "PDF";
    end

    %% Prove Code Quality 
    % Tools required: Polyspace Code Prover
    if includeGenerateCodeTask && includeProveCodeQuality
        pscpTask = pm.addTask(padv.builtin.task.AnalyzeModelCode(Name="ProveCodeQuality"));
        pscpTask.Title = "Prove Code Quality";
        pscpTask.VerificationMode = "CodeProver";
        pscpTask.ResultDir = string(fullfile('$DEFAULTOUTPUTDIR$', ...
            '$ITERATIONARTIFACT$','code_quality'));
        pscpTask.Reports = ["Developer", "CallHierarchy", "VariableAccess"];
        pscpTask.ReportPath = string(fullfile('$DEFAULTOUTPUTDIR$', ...
            '$ITERATIONARTIFACT$','code_quality'));
        pscpTask.ReportNames = [...
            "$ITERATIONARTIFACT$_Developer", ...
            "$ITERATIONARTIFACT$_CallHierarchy", ...
            "$ITERATIONARTIFACT$_VariableAccess"];
        pscpTask.ReportFormat = "PDF";
    end
    

    %% Inspect Code
    % Tools required: Simulink Code Inspector
    if includeGenerateCodeTask && includeCodeInspection
        slciTask = pm.addTask(padv.builtin.task.RunCodeInspection());
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% Set Task relationships
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %% Set Task Dependencies
    if includeGenerateCodeTask && includeCodeInspection
        slciTask.dependsOn(codegenTask);
    end
    if includeGenerateCodeTask && includeAnalyzeModelCode
        psbfTask.dependsOn(codegenTask);
    end
    if includeGenerateCodeTask && includeProveCodeQuality
        pscpTask.dependsOn(codegenTask);
    end
    if includeTestsPerTestCaseTask && includeMergeTestResultsTask
        mergeTestTask.dependsOn(milTask,"WhenStatus",{'Pass','Fail'});
    end

    %% Set Task Run-Order
    if includeModelStandardsTask && includeSimulinkWebViewTask
        maTask.runsAfter(slwebTask);
    end
    if includeDesignErrorDetectionTask && includeModelStandardsTask
        dedTask.runsAfter(maTask);
    end
    if includeModelComparisonTask && includeModelStandardsTask
        mdlCompTask.runsAfter(maTask);
    end
    if includeSDDTask && includeModelStandardsTask
        sddTask.runsAfter(maTask);
    end
    if includeTestsPerTestCaseTask && includeModelStandardsTask
        milTask.runsAfter(maTask);
    end
    if includeGenerateCodeTask && includeAnalyzeModelCode && includeProveCodeQuality
        pscpTask.runsAfter(psbfTask);
    end
    % Set the code generation task to always run after Model Standards,
    % System Design Description and Test tasks
    if includeGenerateCodeTask && includeModelStandardsTask
        codegenTask.runsAfter(maTask);
    end
    if includeGenerateCodeTask && includeSDDTask
        codegenTask.runsAfter(sddTask);
    end
    if includeGenerateCodeTask && includeTestsPerTestCaseTask
        codegenTask.runsAfter(milTask);
    end
    % Both the Polyspace Bug Finder (PSBF) and the Simulink Code Inspector
    % (SLCI) tasks depend on the code generation tasks. SLCI task is set to
    % run after the PSBF task without establishing an execution dependency
    % by using 'runsAfter'.
    if includeGenerateCodeTask && includeAnalyzeModelCode ...
            && includeCodeInspection
        slciTask.runsAfter(psbfTask);
    end

    % !PROCESSMODEL_EDITOR_MARKER! %
    % Do not remove. Process Advisor uses the comment above to automatically add tasks. %
end
