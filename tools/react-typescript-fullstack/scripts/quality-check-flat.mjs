import { spawnSync } from "node:child_process";
import { mkdir, writeFile, access } from "node:fs/promises";
import { resolve, join } from "node:path";
import { fileURLToPath } from "node:url";

const toolRoot=resolve(fileURLToPath(new URL("..",import.meta.url)));
const repoRoot=resolve(toolRoot,"../..");
const targetRoot=resolve(repoRoot,"workspaces/target",process.env.PROJECT_PATH??".");
const outputRoot=resolve(repoRoot,"artifacts/quality");
const binRoot=join(toolRoot,"node_modules/.bin");
const exists=path=>access(path).then(()=>true).catch(()=>false);
const findConfig=async names=>{for(const name of names)if(await exists(join(targetRoot,name)))return name;return null;};
const checks=[
 {name:"typescript",bin:"tsc",args:["--noEmit","--pretty","false"],configs:["tsconfig.json"]},
 {name:"eslint",bin:"eslint",args:[".","--max-warnings=0"],configs:["eslint.config.js","eslint.config.mjs","eslint.config.cjs","eslint.config.ts"]},
 {name:"biome",bin:"biome",args:["check","."],configs:["biome.json","biome.jsonc"]},
 {name:"prettier",bin:"prettier",args:["--check","."],configs:[".prettierrc",".prettierrc.json",".prettierrc.js","prettier.config.js","prettier.config.mjs"]},
 {name:"knip",bin:"knip",args:["--no-progress"],configs:["knip.json","knip.jsonc","knip.ts","knip.config.ts"]},
 {name:"dependency-cruiser",bin:"depcruise",args:["."],configs:[".dependency-cruiser.cjs",".dependency-cruiser.js",".dependency-cruiser.mjs",".dependency-cruiser.json"]}
];
await mkdir(outputRoot,{recursive:true});
if(!(await exists(join(targetRoot,"package.json"))))throw new Error(`package.json not found in ${targetRoot}`);
const results=[];
for(const check of checks){
 const config=await findConfig(check.configs);
 if(!config){results.push({name:check.name,status:"skipped",reason:"No supported project configuration found"});continue;}
 const executable=join(binRoot,check.bin);
 if(!(await exists(executable))){results.push({name:check.name,status:"unavailable",reason:`Tool not installed: ${check.bin}`});continue;}
 const run=spawnSync(executable,check.args,{cwd:targetRoot,encoding:"utf8",env:{...process.env,PATH:`${binRoot}:${process.env.PATH??""}`,CI:"true"},timeout:600000,maxBuffer:20*1024*1024});
 const record={name:check.name,command:[check.bin,...check.args],exitCode:run.status,signal:run.signal??null,error:run.error?.message??null};
 results.push(record);
 await writeFile(join(outputRoot,`${check.name}.log`,),[run.stdout,run.stderr].filter(Boolean).join("\n"));
}
const failed=results.filter(x=>x.exitCode!==undefined&&x.exitCode!==0);
const summary={projectPath:targetRoot,completedAt:new Date().toISOString(),checks:results,failed:failed.map(x=>x.name)};
await writeFile(join(outputRoot,"summary.json"),JSON.stringify(summary,null,2)+"\n");
console.log(JSON.stringify(summary,null,2));
if(failed.length)process.exitCode=1;
