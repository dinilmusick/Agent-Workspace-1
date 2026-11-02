import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readFile, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";

const cli=resolve("tools/looper/looper.mjs");
const contract={
  goal:"Verify Looper state transitions",
  inputContract:{type:"object",required:["source"]},
  outputContract:{type:"object",required:["result"]},
  successCriteria:[{id:"build",description:"Build passes"},{id:"browser",description:"Browser passes"}],
  iterationPolicy:{maxIterations:4,repeatedFailureThreshold:2}
};
async function fixture(fn){
  const dir=await mkdtemp(join(tmpdir(),"looper-test-"));
  try{
    const contractPath=join(dir,"contract.json"),statePath=join(dir,"state.json"),resultPath=join(dir,"iteration.json");
    await writeFile(contractPath,JSON.stringify(contract));
    const run=(...args)=>spawnSync(process.execPath,[cli,...args],{encoding:"utf8"});
    const init=run("init",contractPath,statePath);
    assert.equal(init.status,0,init.stderr);
    const record=async value=>{
      await writeFile(resultPath,JSON.stringify(value));
      const r=run("record",statePath,resultPath);
      assert.equal(r.status,0,r.stderr);
      return {response:JSON.parse(r.stdout),state:JSON.parse(await readFile(statePath,"utf8"))};
    };
    await fn({run,record,statePath});
  }finally{await rm(dir,{recursive:true,force:true});}
}

test("incomplete pass continues and records input/output",()=>fixture(async({record})=>{
  const {response,state}=await record({
    verdict:"pass",input:{source:"repo"},output:{result:"build-only"},
    criterionResults:[{criterionId:"build",status:"satisfied",evidence:["ci://build/1"]}],
    evidence:["ci://build/1"],nextAction:"Run browser checks"
  });
  assert.equal(response.status,"continue");
  assert.equal(response.finished,false);
  assert.deepEqual(state.history[0].input,{source:"repo"});
  assert.deepEqual(state.currentOutput,{result:"build-only"});
  assert.deepEqual(response.unmetCriteria,["browser"]);
}));

test("two identical failures request research but do not finish",()=>fixture(async({record})=>{
  await record({verdict:"error",failureKey:"same-build-error",input:{source:"repo"},output:{result:"error"},observation:"Build failed"});
  const {response,state}=await record({verdict:"error",failureKey:"same-build-error",input:{source:"repo"},output:{result:"error"},observation:"Same build failure"});
  assert.equal(response.status,"research_required");
  assert.equal(response.finished,false);
  assert.equal(response.researchRequired,true);
  assert.equal(state.consecutiveFailureCount,2);
}));

test("completion requires every required criterion and evidence",()=>fixture(async({record})=>{
  const {response,state}=await record({
    verdict:"pass",input:{source:"repo"},output:{result:"verified"},
    criterionResults:[
      {criterionId:"build",status:"satisfied",evidence:["ci://build/1"]},
      {criterionId:"browser",status:"satisfied",evidence:["playwright://trace/1"]}
    ]
  });
  assert.equal(response.status,"completed");
  assert.equal(response.finished,true);
  assert.equal(state.history.length,1);
}));

test("iteration budget stops an unfinished loop",()=>fixture(async({record})=>{
  let last;
  for(let i=0;i<4;i++) last=await record({verdict:"continue",input:{source:"repo"},output:{result:i}});
  assert.equal(last.response.status,"max_iterations");
  assert.equal(last.response.finished,true);
}));

test("blocked state is terminal",()=>fixture(async({record})=>{
  const {response}=await record({verdict:"blocked",blocker:"Missing required repository permission",input:{source:"repo"},output:{result:null}});
  assert.equal(response.status,"blocked");
  assert.equal(response.finished,true);
}));
