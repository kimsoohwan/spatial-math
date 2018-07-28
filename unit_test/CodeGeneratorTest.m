% This is for testing the CodeGenerator functions in the robotics Toolbox
function tests = TransformationsTest
  tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    % Create a test robot based on the first three links of the Puma 560.
    deg = pi/180;
    L(1) = Revolute('d', 0, 'a', 0, 'alpha', pi/2, ...
    'I', [0, 0.35, 0, 0, 0, 0], ...
    'r', [0, 0, 0], ...
    'm', 0, ...
    'Jm', 200e-6, ...
    'G', -62.6111, ...
    'B', 1.48e-3, ...
    'Tc', [0.395 -0.435], ...
    'qlim', [-160 160]*deg );

    L(2) = Revolute('d', 0, 'a', 0.4318, 'alpha', 0, ...
    'I', [0.13, 0.524, 0.539, 0, 0, 0], ...
    'r', [-0.3638, 0.006, 0.2275], ...
    'm', 17.4, ...
    'Jm', 200e-6, ...
    'G', 107.815, ...
    'B', .817e-3, ...
    'Tc', [0.126 -0.071], ...
    'qlim', [-45 225]*deg );
    
    L(3) = Revolute('d', 0.15005, 'a', 0.0203, 'alpha', -pi/2,  ...
    'I', [0.066, 0.086, 0.0125, 0, 0, 0], ...
    'r', [-0.0203, -0.0141, 0.070], ...
    'm', 4.8, ...
    'Jm', 200e-6, ...
    'G', -53.7063, ...
    'B', 1.38e-3, ...
    'Tc', [0.132, -0.105], ...
    'qlim', [-225 45]*deg );

    testRob = SerialLink(L, 'name', 'UnitTestRobot');
    testCase.TestData.rob = testRob.nofriction('all');

    testCase.TestData.nTrials = 10; % number of tests to perform in each subroutine
    
    testCase.TestData.cGen = CodeGenerator(testCase.TestData.rob,'default','logfile','cGenUnitTestLog.txt');
    testCase.TestData.cGen.verbose = 0;
end
    
function teardownOnce(testCase)
    clear mex
    if ~isempty(strfind(path,testCase.TestData.cGen.basepath))
        rmpath(testCase.TestData.cGen.basepath)
        rmdir(testCase.TestData.cGen.basepath, 's')
        delete(testCase.TestData.cGen.logfile);
    end
end
    
    %%
function genfkine_test(testCase)
    % - test generated forward kinematics code
    T = testCase.TestData.cGen.genfkine; % generate symbolic expressions and m-files
    addpath(testCase.TestData.cGen.basepath);
    
    specRob = eval(testCase.TestData.cGen.getrobfname);
    symQ = testCase.TestData.rob.gencoords;
    
    Q = rand(testCase.TestData.nTrials,specRob.n);
    resRTB = rand(4,4,testCase.TestData.nTrials);
    resSym = rand(4,4,testCase.TestData.nTrials);
    resM = rand(4,4,testCase.TestData.nTrials);
    resMEX = rand(4,4,testCase.TestData.nTrials);
    
    profile on
    % test symbolics and generated m-code
    for iTry = 1:testCase.TestData.nTrials
        q = Q(iTry,:);
        
        resRTB(:,:,iTry) =  testCase.TestData.rob.fkine(q).T;
        resSym(:,:,iTry) = subs(T.T,symQ,q);
        resM(:,:,iTry) = specRob.fkine(q);
    end
    profile off;
    pstat = profile('info');
    statRTB = getprofilefunctionstats(pstat,['SerialLink',filesep,'fkine']);
    statSym = getprofilefunctionstats(pstat,['sym',filesep,'subs']);
    statM = getprofilefunctionstats(pstat,[testCase.TestData.cGen.getrobfname,filesep,'fkine']);
    profile clear;
    clear('specRob');
    rmpath(testCase.TestData.cGen.basepath)
    
    % assertions so far?
    verifyEqual(testCase, resRTB, resSym, 'absTol', 1e-6);
    verifyEqual(testCase, resRTB, resM, 'absTol', 1e-6);
    
    testCase.TestData.cGen.genccodefkine;
    testCase.TestData.cGen.genmexfkine;
    
    addpath(testCase.TestData.cGen.basepath);
    specRob = eval(testCase.TestData.cGen.getrobfname);
    
    profile on;
    % test generated mex code
    for iTry = 1:testCase.TestData.nTrials
        q = Q(iTry,:);
        resMEX(:,:,iTry) = specRob.fkine(q);
    end
    profile off;
    pstat = profile('info');
    statMEX = getprofilefunctionstats(pstat,[testCase.TestData.cGen.getrobfname,filesep,'fkine.',mexext],'mex-function');
    
    verifyEqual(testCase, resRTB, resMEX, 'absTol', 1e-6);
    
    tRTB = statRTB.TotalTime/statRTB.NumCalls;
    tSym = statSym.TotalTime/statSym.NumCalls;
    tM = statM.TotalTime/statM.NumCalls;
    tMEX = statMEX.TotalTime/statMEX.NumCalls;
    fprintf('RTB function time(testCase): %f\n', tRTB)
    fprintf('Sym function time(testCase): %f  speedups: %f to RTB\n',tSym, tRTB/tSym);
    fprintf('M function time(testCase): %f  speedups: %f  to RTB,  %f  to Sym\n',tM, tRTB/tM, tSym/tM);
    fprintf('MEX function time(testCase): %f  speedups: %f  to RTB,  %f  to Sym, %f to M\n',tMEX, tRTB/tMEX, tSym/tMEX, tM/tMEX);
end
    
    %%
function genjacobian_test(testCase)
    % - test generated differential kinematics code
    [J0, Jn] = testCase.TestData.cGen.genjacobian;
    addpath(testCase.TestData.cGen.basepath);
    
    specRob = eval(testCase.TestData.cGen.getrobfname);
    symQ = testCase.TestData.rob.gencoords;
    
    Q = rand(testCase.TestData.nTrials,specRob.n);
    resRTB0 = rand(6,specRob.n,testCase.TestData.nTrials);
    resSym0 = rand(6,specRob.n,testCase.TestData.nTrials);
    resM0 = rand(6,specRob.n,testCase.TestData.nTrials);
    resMEX0 = rand(6,specRob.n,testCase.TestData.nTrials);
    resRTBn = rand(6,specRob.n,testCase.TestData.nTrials);
    resSymn = rand(6,specRob.n,testCase.TestData.nTrials);
    resMn = rand(6,specRob.n,testCase.TestData.nTrials);
    resMEXn = rand(6,specRob.n,testCase.TestData.nTrials);
    
    profile on
    % test symbolics and generated m-code
    for iTry = 1:testCase.TestData.nTrials
        q = Q(iTry,:);
        
        resRTB0(:,:,iTry) =  testCase.TestData.rob.jacob0(q);
        resSym0(:,:,iTry) = subs(J0,symQ,q);
        resM0(:,:,iTry) = specRob.jacob0(q);
        
        resRTBn(:,:,iTry) =  testCase.TestData.rob.jacobe(q);
        resSymn(:,:,iTry) = subs(Jn,symQ,q);
        resMn(:,:,iTry) = specRob.jacobe(q);
    end
    profile off;
    pstat = profile('info');
    statRTB = getprofilefunctionstats(pstat,['SerialLink',filesep,'jacob0']);
    statSym = getprofilefunctionstats(pstat,['sym',filesep,'subs']);
    statM = getprofilefunctionstats(pstat,[testCase.TestData.cGen.getrobfname,filesep,'jacob0']);
    profile clear;
    clear('specRob');
    rmpath(testCase.TestData.cGen.basepath)
    
    % assertions so far?
    verifyEqual(testCase, resRTB0, resSym0, 'absTol', 1e-6);
    verifyEqual(testCase, resRTB0, resM0, 'absTol', 1e-6);
    verifyEqual(testCase, resRTBn, resSymn, 'absTol', 1e-6);
    verifyEqual(testCase, resRTBn, resMn, 'absTol', 1e-6);
    
    testCase.TestData.cGen.genccodejacobian;
    testCase.TestData.cGen.genmexjacobian;
    
    addpath(testCase.TestData.cGen.basepath);
    specRob = eval(testCase.TestData.cGen.getrobfname);
    
    profile on;
    % test generated mex code
    for iTry = 1:testCase.TestData.nTrials
        q = Q(iTry,:);
        resMEX0(:,:,iTry) = specRob.jacob0(q);
        resMEXn(:,:,iTry) = specRob.jacobe(q);
    end
    profile off;
    pstat = profile('info');
    statMEX = getprofilefunctionstats(pstat,[testCase.TestData.cGen.getrobfname,filesep,'jacob0.',mexext],'mex-function');
    
    verifyEqual(testCase, resRTB0, resMEX0, 'absTol', 1e-6);
    verifyEqual(testCase, resRTBn, resMEXn, 'absTol', 1e-6);
    
    tRTB = statRTB.TotalTime/statRTB.NumCalls;
    tSym = statSym.TotalTime/statSym.NumCalls;
    tM = statM.TotalTime/statM.NumCalls;
    tMEX = statMEX.TotalTime/statMEX.NumCalls;
    
    fprintf('RTB function time(testCase): %f\n', tRTB)
    fprintf('Sym function time(testCase): %f  speedups: %f to RTB\n',tSym, tRTB/tSym);
    fprintf('M function time(testCase): %f  speedups: %f  to RTB,  %f  to Sym\n',tM, tRTB/tM, tSym/tM);
    fprintf('MEX function time(testCase): %f  speedups: %f  to RTB,  %f  to Sym, %f to M\n',tMEX, tRTB/tMEX, tSym/tMEX, tM/tMEX);
end
    
    %%
function geninertia_test(testCase)
    % - test inertial matrix against numeric version
    [I] = testCase.TestData.cGen.geninertia;
    
    addpath(testCase.TestData.cGen.basepath);
    
    specRob = eval(testCase.TestData.cGen.getrobfname);
    symQ = testCase.TestData.rob.gencoords;
    
    Q = rand(testCase.TestData.nTrials,specRob.n);
    resRTB = rand(specRob.n,specRob.n,testCase.TestData.nTrials);
    resSym = rand(specRob.n,specRob.n,testCase.TestData.nTrials);
    resM = rand(specRob.n,specRob.n,testCase.TestData.nTrials);
    resMEX = rand(specRob.n,specRob.n,testCase.TestData.nTrials);
    
    profile on
    % test symbolics and generated m-code
    for iTry = 1:testCase.TestData.nTrials
        q = Q(iTry,:);
        
        resRTB(:,:,iTry) =  testCase.TestData.rob.inertia(q);
        resSym(:,:,iTry) = subs(I,symQ,q);
        resM(:,:,iTry) = specRob.inertia(q);
        
    end
    profile off;
    pstat = profile('info');
    statRTB = getprofilefunctionstats(pstat,['SerialLink',filesep,'inertia']);
    statSym = getprofilefunctionstats(pstat,['sym',filesep,'subs']);
    statM = getprofilefunctionstats(pstat,[testCase.TestData.cGen.getrobfname,filesep,'inertia']);
    profile clear;
    clear('specRob');
    rmpath(testCase.TestData.cGen.basepath)
    
    % assertions so far?
    verifyEqual(testCase, resRTB, resSym, 'absTol', 1e-6);
    verifyEqual(testCase, resRTB, resM, 'absTol', 1e-6);
    
    
    testCase.TestData.cGen.genccodeinertia;
    testCase.TestData.cGen.genmexinertia;
    
    addpath(testCase.TestData.cGen.basepath);
    specRob = eval(testCase.TestData.cGen.getrobfname);
    
    profile on;
    % test generated mex code
    for iTry = 1:testCase.TestData.nTrials
        q = Q(iTry,:);
        resMEX(:,:,iTry) = specRob.inertia(q);
    end
    profile off;
    pstat = profile('info');
    statMEX = getprofilefunctionstats(pstat,[testCase.TestData.cGen.getrobfname,filesep,'inertia.',mexext],'mex-function');
    
    verifyEqual(testCase, resRTB, resMEX, 'absTol', 1e-6);
    
    
    tRTB = statRTB.TotalTime/statRTB.NumCalls;
    tSym = statSym.TotalTime/statSym.NumCalls;
    tM = statM.TotalTime/statM.NumCalls;
    tMEX = statMEX.TotalTime/statMEX.NumCalls;
    
    fprintf('RTB function time(testCase): %f\n', tRTB)
    fprintf('Sym function time(testCase): %f  speedups: %f to RTB\n',tSym, tRTB/tSym);
    fprintf('M function time(testCase): %f  speedups: %f  to RTB,  %f  to Sym\n',tM, tRTB/tM, tSym/tM);
    fprintf('MEX function time(testCase): %f  speedups: %f  to RTB,  %f  to Sym, %f to M\n',tMEX, tRTB/tMEX, tSym/tMEX, tM/tMEX);
end
    
    
function gencoriolis_test(testCase)
    % - test coriolis matrix against numeric version
    [C] = testCase.TestData.cGen.gencoriolis;
    
    addpath(testCase.TestData.cGen.basepath);
    
    specRob = eval(testCase.TestData.cGen.getrobfname);
    [symQ symQD] = testCase.TestData.rob.gencoords;
    
    Q = rand(testCase.TestData.nTrials,specRob.n);
    QD = rand(testCase.TestData.nTrials,specRob.n);
    resRTB = rand(specRob.n,specRob.n,testCase.TestData.nTrials);
    resSym = rand(specRob.n,specRob.n,testCase.TestData.nTrials);
    resM = rand(specRob.n,specRob.n,testCase.TestData.nTrials);
    resMEX = rand(specRob.n,specRob.n,testCase.TestData.nTrials);
    
    profile on
    % test symbolics and generated m-code
    for iTry = 1:testCase.TestData.nTrials
        q = Q(iTry,:);
        qd = QD(iTry,:);
        
        resRTB(:,:,iTry) =  testCase.TestData.rob.coriolis(q,qd);
        resSym(:,:,iTry) = subs(subs(C,symQ,q),symQD,qd);
        resM(:,:,iTry) = specRob.coriolis(q,qd);
        
    end
    profile off;
    pstat = profile('info');
    statRTB = getprofilefunctionstats(pstat,['SerialLink',filesep,'coriolis']);
    statSym = getprofilefunctionstats(pstat,['sym',filesep,'subs']);
    statM = getprofilefunctionstats(pstat,[testCase.TestData.cGen.getrobfname,filesep,'coriolis']);
    profile clear;
    clear('specRob');
    rmpath(testCase.TestData.cGen.basepath)
    
    % assertions so far?
    verifyEqual(testCase, resRTB, resSym, 'absTol', 1e-6);
    verifyEqual(testCase, resRTB, resM, 'absTol', 1e-6);
    
    
    testCase.TestData.cGen.genccodecoriolis;
    testCase.TestData.cGen.genmexcoriolis;
    
    addpath(testCase.TestData.cGen.basepath);
    specRob = eval(testCase.TestData.cGen.getrobfname);
    
    profile on;
    % test generated mex code
    for iTry = 1:testCase.TestData.nTrials
        q = Q(iTry,:);
        qd = QD(iTry,:);
        resMEX(:,:,iTry) = specRob.coriolis(q,qd);
    end
    profile off;
    pstat = profile('info');
    statMEX = getprofilefunctionstats(pstat,[testCase.TestData.cGen.getrobfname,filesep,'coriolis.',mexext],'mex-function');
    
    verifyEqual(testCase, resRTB, resMEX, 'absTol', 1e-6);
    
    
    tRTB = statRTB.TotalTime/statRTB.NumCalls;
    tSym = statSym.TotalTime/statSym.NumCalls;
    tM = statM.TotalTime/statM.NumCalls;
    tMEX = statMEX.TotalTime/statMEX.NumCalls;
    
    fprintf('RTB function time(testCase): %f\n', tRTB)
    fprintf('Sym function time(testCase): %f  speedups: %f to RTB\n',tSym, tRTB/tSym);
    fprintf('M function time(testCase): %f  speedups: %f  to RTB,  %f  to Sym\n',tM, tRTB/tM, tSym/tM);
    fprintf('MEX function time(testCase): %f  speedups: %f  to RTB,  %f  to Sym, %f to M\n',tMEX, tRTB/tMEX, tSym/tMEX, tM/tMEX);
end
    
    %%
function gengravload_test(testCase)
    % - test vector of gravitational load against numeric version
    [g] = testCase.TestData.cGen.gengravload;
    
    addpath(testCase.TestData.cGen.basepath);
    
    specRob = eval(testCase.TestData.cGen.getrobfname);
    symQ = testCase.TestData.rob.gencoords;
    
    Q = rand(testCase.TestData.nTrials,specRob.n);
    resRTB = rand(specRob.n,1,testCase.TestData.nTrials);
    resSym = rand(specRob.n,1,testCase.TestData.nTrials);
    resM = rand(specRob.n,1,testCase.TestData.nTrials);
    resMEX = rand(specRob.n,1,testCase.TestData.nTrials);
    
    profile on
    % test symbolics and generated m-code
    for iTry = 1:testCase.TestData.nTrials
        q = Q(iTry,:);
        
        resRTB(:,:,iTry) =  testCase.TestData.rob.gravload(q);
        resSym(:,:,iTry) = subs(g,symQ,q);
        resM(:,:,iTry) = specRob.gravload(q);
        
    end
    profile off;
    pstat = profile('info');
    statRTB = getprofilefunctionstats(pstat,['SerialLink',filesep,'gravload']);
    statSym = getprofilefunctionstats(pstat,['sym',filesep,'subs']);
    statM = getprofilefunctionstats(pstat,[testCase.TestData.cGen.getrobfname,filesep,'gravload']);
    profile clear;
    clear('specRob');
    rmpath(testCase.TestData.cGen.basepath)
    
    % assertions so far?
    verifyEqual(testCase, resRTB, resSym, 'absTol', 1e-6);
    verifyEqual(testCase, resRTB, resM, 'absTol', 1e-6);
    
    
    testCase.TestData.cGen.genccodegravload;
    testCase.TestData.cGen.genmexgravload;
    
    addpath(testCase.TestData.cGen.basepath);
    specRob = eval(testCase.TestData.cGen.getrobfname);
    
    profile on;
    % test generated mex code
    for iTry = 1:testCase.TestData.nTrials
        q = Q(iTry,:);
        resMEX(:,:,iTry) = specRob.gravload(q);
    end
    profile off;
    pstat = profile('info');
    statMEX = getprofilefunctionstats(pstat,[testCase.TestData.cGen.getrobfname,filesep,'gravload.',mexext],'mex-function');
    
    verifyEqual(testCase, resRTB, resMEX, 'absTol', 1e-6);
    
    
    tRTB = statRTB.TotalTime/statRTB.NumCalls;
    tSym = statSym.TotalTime/statSym.NumCalls;
    tM = statM.TotalTime/statM.NumCalls;
    tMEX = statMEX.TotalTime/statMEX.NumCalls;
    
    fprintf('RTB function time(testCase): %f\n', tRTB)
    fprintf('Sym function time(testCase): %f  speedups: %f to RTB\n',tSym, tRTB/tSym);
    fprintf('M function time(testCase): %f  speedups: %f  to RTB,  %f  to Sym\n',tM, tRTB/tM, tSym/tM);
    fprintf('MEX function time(testCase): %f  speedups: %f  to RTB,  %f  to Sym, %f to M\n',tMEX, tRTB/tMEX, tSym/tMEX, tM/tMEX);
end

function genfriction_test(testCase)
    % - test friction vector against numeric version
    [F] = testCase.TestData.cGen.genfriction;
    
    addpath(testCase.TestData.cGen.basepath);
    
    specRob = eval(testCase.TestData.cGen.getrobfname);
    [~, symQD] = testCase.TestData.rob.gencoords;
    
    QD = rand(testCase.TestData.nTrials,specRob.n);
    resRTB = rand(specRob.n,1,testCase.TestData.nTrials);
    resSym = rand(specRob.n,1,testCase.TestData.nTrials);
    resM = rand(specRob.n,1,testCase.TestData.nTrials);
    resMEX = rand(specRob.n,1,testCase.TestData.nTrials);
    
    profile on
    % test symbolics and generated m-code
    for iTry = 1:testCase.TestData.nTrials
        qd = QD(iTry,:);
        
        resRTB(:,:,iTry) =  testCase.TestData.rob.friction(qd);
        resSym(:,:,iTry) = subs(F,symQD,qd);
        resM(:,:,iTry) = specRob.friction(qd);
        
    end
    profile off;
    pstat = profile('info');
    statRTB = getprofilefunctionstats(pstat,['SerialLink',filesep,'friction']);
    statSym = getprofilefunctionstats(pstat,['sym',filesep,'subs']);
    statM = getprofilefunctionstats(pstat,[testCase.TestData.cGen.getrobfname,filesep,'friction']);
    profile clear;
    clear('specRob');
    rmpath(testCase.TestData.cGen.basepath)
    
    % assertions so far?
    verifyEqual(testCase, resRTB, resSym, 'absTol', 1e-6);
    verifyEqual(testCase, resRTB, resM, 'absTol', 1e-6);
    
    
    testCase.TestData.cGen.genccodefriction;
    testCase.TestData.cGen.genmexfriction;
    
    addpath(testCase.TestData.cGen.basepath);
    specRob = eval(testCase.TestData.cGen.getrobfname);
    
    profile on;
    % test generated mex code
    for iTry = 1:testCase.TestData.nTrials
        qd = QD(iTry,:);
        resMEX(:,:,iTry) = specRob.friction(qd);
    end
    profile off;
    pstat = profile('info');
    statMEX = getprofilefunctionstats(pstat,[testCase.TestData.cGen.getrobfname,filesep,'friction.',mexext],'mex-function');
    
    verifyEqual(testCase, resRTB, resMEX, 'absTol', 1e-6);
    
    
    tRTB = statRTB.TotalTime/statRTB.NumCalls;
    tSym = statSym.TotalTime/statSym.NumCalls;
    tM = statM.TotalTime/statM.NumCalls;
    tMEX = statMEX.TotalTime/statMEX.NumCalls;
    
    fprintf('RTB function time(testCase): %f\n', tRTB)
    fprintf('Sym function time(testCase): %f  speedups: %f to RTB\n',tSym, tRTB/tSym);
    fprintf('M function time(testCase): %f  speedups: %f  to RTB,  %f  to Sym\n',tM, tRTB/tM, tSym/tM);
    fprintf('MEX function time(testCase): %f  speedups: %f  to RTB,  %f  to Sym, %f to M\n',tMEX, tRTB/tMEX, tSym/tMEX, tM/tMEX);
end
    
function geninvdyn_test(testCase)
    % - test inverse dynamics against numeric version
    tau = testCase.TestData.cGen.geninvdyn;
    
    addpath(testCase.TestData.cGen.basepath);
    
    specRob = eval(testCase.TestData.cGen.getrobfname);
    [symQ, symQD, symQDD] = testCase.TestData.rob.gencoords;
    
    Q = rand(testCase.TestData.nTrials,specRob.n);
    QD = 0*rand(testCase.TestData.nTrials,specRob.n);
    QDD = 0*rand(testCase.TestData.nTrials,specRob.n);
    resRTB = rand(specRob.n,1,testCase.TestData.nTrials);
    resSym = rand(specRob.n,1,testCase.TestData.nTrials);
    resM = rand(specRob.n,1,testCase.TestData.nTrials);
    resMEX = rand(specRob.n,1,testCase.TestData.nTrials);
    
    profile on
    % test symbolics and generated m-code
    for iTry = 1:testCase.TestData.nTrials
        q = Q(iTry,:);
        qd = QD(iTry,:);
        qdd = QDD(iTry,:);
        
        resRTB(:,:,iTry) =  testCase.TestData.rob.rne(q,qd,qdd);
        resSym(:,:,iTry) = subs(subs(subs(tau,symQ,q),symQD,qd),symQDD,qdd);
        resM(:,:,iTry) = specRob.invdyn(q, qd, qdd);
        
    end
    profile off;
    pstat = profile('info');
    statRTB = getprofilefunctionstats(pstat,['SerialLink',filesep,'rne']);
    statSym = getprofilefunctionstats(pstat,['sym',filesep,'subs']);
    statM = getprofilefunctionstats(pstat,[testCase.TestData.cGen.getrobfname,filesep,'invdyn']);
    profile clear;
    clear('specRob');
    rmpath(testCase.TestData.cGen.basepath)
    
    % assertions so far?
    verifyEqual(testCase, resRTB, resSym, 'absTol', 1e-6);
    verifyEqual(testCase, resRTB, resM, 'absTol', 1e-6);
    
    
    testCase.TestData.cGen.genccodeinvdyn;
    testCase.TestData.cGen.genmexinvdyn;
    
    addpath(testCase.TestData.cGen.basepath);
    specRob = eval(testCase.TestData.cGen.getrobfname);
    
    profile on;
    % test generated mex code
    for iTry = 1:testCase.TestData.nTrials
        q = Q(iTry,:);
        qd = QD(iTry,:);
        qdd = QDD(iTry,:);
        
        resMEX(:,:,iTry) = specRob.invdyn(q,qd,qdd);
    end
    profile off;
    pstat = profile('info');
    statMEX = getprofilefunctionstats(pstat,[testCase.TestData.cGen.getrobfname,filesep,'invdyn.',mexext],'mex-function');
    
    verifyEqual(testCase, resRTB, resMEX, 'absTol', 1e-6);
    
    tRTB = statRTB.TotalTime/statRTB.NumCalls;
    tSym = statSym.TotalTime/statSym.NumCalls;
    tM = statM.TotalTime/statM.NumCalls;
    tMEX = statMEX.TotalTime/statMEX.NumCalls;
    
    fprintf('RTB function time(testCase): %f\n', tRTB)
    fprintf('Sym function time(testCase): %f  speedups: %f to RTB\n',tSym, tRTB/tSym);
    fprintf('M function time(testCase): %f  speedups: %f  to RTB,  %f  to Sym\n',tM, tRTB/tM, tSym/tM);
    fprintf('MEX function time(testCase): %f  speedups: %f  to RTB,  %f  to Sym, %f to M\n',tMEX, tRTB/tMEX, tSym/tMEX, tM/tMEX);
end
    
    
function genfdyn_test(testCase)
    % - test forward dynamics against numeric version
    IqddSym = testCase.TestData.cGen.genfdyn.';
    
    addpath(testCase.TestData.cGen.basepath);
    
    specRob = eval(testCase.TestData.cGen.getrobfname);
    [symQ, symQD] = testCase.TestData.rob.gencoords;
    symTau = testCase.TestData.rob.genforces;
    
    Q = rand(testCase.TestData.nTrials,specRob.n);
    QD = rand(testCase.TestData.nTrials,specRob.n);
    TAU = rand(testCase.TestData.nTrials,specRob.n);
    resRTB = zeros(specRob.n,1,testCase.TestData.nTrials);
    resSym = zeros(specRob.n,1,testCase.TestData.nTrials);
    resM = zeros(specRob.n,1,testCase.TestData.nTrials);
    resMEX = zeros(specRob.n,1,testCase.TestData.nTrials);
    
    
    delete('zahlen.txt')
    delete('zahlenmatlab.txt')
    
    fid = fopen('zahlenmatlab.txt','w');


    profile on
    % test symbolics and generated m-code
    for iTry = 1:testCase.TestData.nTrials
        q = Q(iTry,:);
        qd = QD(iTry,:);
        tau = TAU(iTry,:);
        
        resRTB(:,:,iTry) =  testCase.TestData.rob.accel(q,qd,tau);
        resSym(:,:,iTry) = subs(subs(subs(IqddSym,symQ,q),symQD,qd),symTau,tau);
        resM(:,:,iTry) = specRob.accel(q, qd, tau);
        
        inertia = testCase.TestData.rob.inertia(q);
        invinertia = inv(inertia);
        
        tmpTau = tau  - testCase.TestData.rob.coriolis(q, qd) -  testCase.TestData.rob.gravload(q) +  testCase.TestData.rob.friction(qd);
        
        fprintf(fid,'\n ------------------------------------------- \n');
        
        fprintf(fid,'q: %f %f %f\n', q(1),q(2),q(3));
        fprintf(fid,'qd: %f %f %f\n', qd(1),qd(2),qd(3));
        fprintf(fid,'tau: %f %f %f\n', tau(1),tau(2),tau(3));
        
        fprintf(fid,'Inertia 1: %f %f %f\n', inertia(1,1),inertia(1,2),inertia(1,3));
        fprintf(fid,'Inertia 2: %f %f %f\n', inertia(2,1),inertia(2,2),inertia(2,3));
        fprintf(fid,'Inertia 3: %f %f %f\n', inertia(3,1),inertia(3,2),inertia(3,3));
        
        fprintf(fid,'\n\n');
        
        fprintf(fid,'Inv Inertia 1: %f %f %f\n', invinertia(1,1),invinertia(1,2),invinertia(1,3));
        fprintf(fid,'Inv Inertia 2: %f %f %f\n', invinertia(2,1),invinertia(2,2),invinertia(2,3));
        fprintf(fid,'Inv Inertia 3: %f %f %f\n', invinertia(3,1),invinertia(3,2),invinertia(3,3));
        
        fprintf(fid,'\n\n');
        
        fprintf(fid,'QDD: %f %f %f\n', resRTB(1,1,iTry), resRTB(2,1,iTry), resRTB(3,1,iTry));

        fprintf(fid,'\n\n');
        
        fprintf(fid, 'tmpTau: %f %f %f\n', tmpTau(1), tmpTau(2), tmpTau(3));

        fprintf(fid,'\n\n');
        
    end
    profile off;
    
    fclose(fid)
    
    pstat = profile('info');
    statRTB = getprofilefunctionstats(pstat,['SerialLink',filesep,'accel']);
    statSym = getprofilefunctionstats(pstat,['sym',filesep,'subs']);
    statM = getprofilefunctionstats(pstat,[testCase.TestData.cGen.getrobfname,filesep,'accel']);
    profile clear;
    clear('specRob');
    rmpath(testCase.TestData.cGen.basepath)
    
    % assertions so far?
    verifyEqual(testCase, resRTB, resM, 'absTol', 1e-6);
    % verifyEqual(testCase, resRTB, resSym);
    
    testCase.TestData.cGen.genccodefdyn;
    testCase.TestData.cGen.genmexfdyn;
    
    addpath(testCase.TestData.cGen.basepath);
    specRob = eval(testCase.TestData.cGen.getrobfname);
    
    profile on;
    % test generated mex code
    
%     delete('zahlen.txt')
%     delete('zahlenmatlab.txt')
    
%     fid = fopen('zahlenmatlab.txt','w');

    for iTry = 1:testCase.TestData.nTrials
        q = Q(iTry,:);
        qd = QD(iTry,:);
        tau = TAU(iTry,:);
        
        resMEX(:,:,iTry) = specRob.accel(q,qd,tau);

%         disp('nothing')
%         inertia = specRob.inertia(q);
%         invinertia = inv(inertia);
        
%         fprintf(fid,'\n ------------------------------------------- \n');
%         
%         fprintf(fid,'q: %f %f %f\n', q(1),q(2),q(3));
%         fprintf(fid,'qd: %f %f %f\n', qd(1),qd(2),qd(3));
%         fprintf(fid,'tau: %f %f %f\n', tau(1),tau(2),tau(3));
%         
%         fprintf(fid,'Inertia 1: %f %f %f\n', inertia(1,1),inertia(1,2),inertia(1,3));
%         fprintf(fid,'Inertia 2: %f %f %f\n', inertia(2,1),inertia(2,2),inertia(2,3));
%         fprintf(fid,'Inertia 3: %f %f %f\n', inertia(3,1),inertia(3,2),inertia(3,3));
%         
%         fprintf(fid,'\n\n');
%         
%         fprintf(fid,'Inv Inertia 1: %f %f %f\n', invinertia(1,1),invinertia(1,2),invinertia(1,3));
%         fprintf(fid,'Inv Inertia 2: %f %f %f\n', invinertia(2,1),invinertia(2,2),invinertia(2,3));
%         fprintf(fid,'Inv Inertia 3: %f %f %f\n', invinertia(3,1),invinertia(3,2),invinertia(3,3));
%         
%         fprintf(fid,'QDD: %f %f %f\n', resMEX(1,1,iTry), resMEX(2,1,iTry), resMEX(3,1,iTry));
% 
%         fprintf(fid,'\n\n');

    end
%     fclose(fid);
    
    
    profile off;
    pstat = profile('info');
    statMEX = getprofilefunctionstats(pstat,[testCase.TestData.cGen.getrobfname,filesep,'accel.',mexext],'mex-function');
    
    z = abs(resRTB-resMEX);
    max(z(:))
    verifyEqual(testCase, resRTB, resMEX, 'absTol', 1e-6);
    
    tRTB = statRTB.TotalTime/statRTB.NumCalls;
    tSym = statSym.TotalTime/statSym.NumCalls;
    tM = statM.TotalTime/statM.NumCalls;
    tMEX = statMEX.TotalTime/statMEX.NumCalls;
    
    fprintf('RTB function time(testCase): %f\n', tRTB)
    fprintf('Sym function time(testCase): %f  speedups: %f to RTB\n',tSym, tRTB/tSym);
    fprintf('M function time(testCase): %f  speedups: %f  to RTB,  %f  to Sym\n',tM, tRTB/tM, tSym/tM);
    fprintf('MEX function time(testCase): %f  speedups: %f  to RTB,  %f  to Sym, %f to M\n',tMEX, tRTB/tMEX, tSym/tMEX, tM/tMEX);
end
