import { chromium } from "playwright";
import AxeBuilder from "@axe-core/playwright";
import { mkdir, writeFile } from "node:fs/promises";

const baseURL=process.env.TARGET_BASE_URL ?? "http://127.0.0.1:4173";
const outputDir=process.env.ARTIFACT_DIR ?? "artifacts/browser";
const report={baseURL,consoleErrors:[],pageErrors:[],requestFailures:[],httpErrors:[]};
await mkdir(outputDir,{recursive:true});
const browser=await chromium.launch({headless:true});
try{
 const context=await browser.newContext({viewport:{width:1440,height:1000}});
 await context.tracing.start({screenshots:true,snapshots:true,sources:true});
 const page=await context.newPage();
 page.on("console",m=>{if(m.type()==="error")report.consoleErrors.push({text:m.text(),location:m.location()});});
 page.on("pageerror",e=>report.pageErrors.push({name:e.name,message:e.message,stack:e.stack}));
 page.on("requestfailed",r=>report.requestFailures.push({url:r.url(),method:r.method(),error:r.failure()?.errorText}));
 page.on("response",r=>{if(r.status()>=400)report.httpErrors.push({url:r.url(),status:r.status(),statusText:r.statusText()});});
 const response=await page.goto(baseURL,{waitUntil:"networkidle",timeout:60000}).catch(e=>{report.navigationError=e.message;return null;});
 report.navigationStatus=response?.status()??null;
 report.title=await page.title().catch(()=>"");
 report.url=page.url();
 await page.screenshot({path:`${outputDir}/initial-page.png`,fullPage:true}).catch(e=>{report.screenshotError=e.message;});
 await writeFile(`${outputDir}/dom.txt`,await page.locator("body").innerText().catch(e=>e.message));
 if(response?.ok()){
  const axe=await new AxeBuilder({page}).withTags(["wcag2a","wcag2aa","wcag21a","wcag21aa"]).analyze();
  report.accessibility={violations:axe.violations.map(v=>({id:v.id,impact:v.impact,description:v.description,help:v.help,helpUrl:v.helpUrl,nodes:v.nodes.map(n=>({target:n.target,failureSummary:n.failureSummary}))})),passes:axe.passes.length,incomplete:axe.incomplete.length};
 }
 await context.tracing.stop({path:`${outputDir}/trace.zip`});
 const failureCount=report.consoleErrors.length+report.pageErrors.length+report.requestFailures.length+report.httpErrors.length;
 report.completedAt=new Date().toISOString();
 await writeFile(`${outputDir}/diagnostics.json`,JSON.stringify(report,null,2));
 console.log(JSON.stringify({navigationStatus:report.navigationStatus,title:report.title,runtimeFailureCount:failureCount,accessibilityViolationCount:report.accessibility?.violations.length??null,outputDir},null,2));
 if(!response?.ok()||failureCount>0)process.exitCode=1;
}finally{await browser.close();}
