//Scripted Pipeline
node {

		stage('Git_Clone'){
		    git branch: 'main', 
            credentialsId: 'jenkins-common-creds', 
            url: 'https://github.com/ttakara/ProcessAdvisorExample.git'
		}
		

        // Requires MATLAB plugin
		stage('Pipeline Generation'){
            
            env.PATH = "C:\\Program Files\\MATLAB\\R2023b\\bin;${env.PATH}"
            
            /* Open the project and generate the pipeline using
            appropriate options */

            runMATLABCommand '''cp = openProject(pwd);
            padv.pipeline.generatePipeline(...
            padv.pipeline.JenkinsOptions(...
            PipelineArchitecture = padv.pipeline.Architecture.SerialStagesGroupPerTask,...
            GeneratedJenkinsFileName = "simulink_pipeline",...
            GeneratedPipelineDirectory = fullfile("derived","pipeline")));'''
		}

        
        // pass necessary environment variables to generated pipeline
		withEnv(["PATH=C:\\Program Files\\MATLAB\\R2023b\\bin;${env.PATH}"]) {    
			
            def rootDir = pwd()
            
            /* This file is generated automatically by 
            padv.pipeline.generatePipeline with a default name 
            of simulink_pipeline. Update this field if the 
            name or location of the generated pipeline file is changed */

			load "${rootDir}/derived/pipeline/simulink_pipeline"  
		}
}