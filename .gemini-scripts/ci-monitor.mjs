#!/usr/bin/env node

/**
 * @license
 * Copyright 2026 Google LLC
 * SPDX-License-Identifier: Apache-2.0
 */

import { execSync } from 'node:child_process';

const BRANCH = process.argv[2] || execSync('git branch --show-current').toString().trim();
const RUN_ID_OVERRIDE = process.argv[3];
const WORKFLOW_OVERRIDE = process.argv[4];

let REPO;
try {
  const remoteUrl = execSync('git remote get-url origin').toString().trim();
  REPO = remoteUrl.replace(/.*github\.com[\/:]/, '').replace(/\.git$/, '').trim();
} catch (e) {
  REPO = 'google-gemini/gemini-cli';
}

const FAILED_FILES = new Set();

function runGh(args) {
  try {
    return execSync(`gh ${args}`, { stdio: ['ignore', 'pipe', 'ignore'] }).toString();
  } catch (e) {
    return null;
  }
}

function fetchFailuresViaApi(jobId) {
  try {
    const cmd = `gh api repos/${REPO}/actions/jobs/${jobId}/logs | grep -iE " FAIL |❌|ERROR|Lint failed|Build failed|Exception|failed with exit code"|❌|ERROR|Lint failed|Build failed"`;
    return execSync(cmd, { stdio: ['ignore', 'pipe', 'ignore'], maxBuffer: 10 * 1024 * 1024 }).toString();
  } catch (e) {
    return "";
  }
}

function extractTestFile(failureText) {
  const cleanLine = failureText.replace(/[|#\[\]()]/g, " ").replace(/<[^>]*>/g, " ").trim();
  const fileMatch = cleanLine.match(/([\w\/._-]+\.test\.[jt]sx?)/);
  if (fileMatch) return fileMatch[1];
  return null;
}

function generateTestCommand(failedFilesMap) {
  const workspaceToFiles = new Map();
  for (const [file, info] of failedFilesMap.entries()) {
    if (["Job Error", "Unknown File", "Build Error", "Lint Error"].includes(file)) continue;
    let workspace = "@google/gemini-cli";
    let relPath = file;
    if (file.startsWith("packages/core/")) {
      workspace = "@google/gemini-cli-core";
      relPath = file.replace("packages/core/", "");
    } else if (file.startsWith("packages/cli/")) {
      workspace = "@google/gemini-cli";
      relPath = file.replace("packages/cli/", "");
    }
    relPath = relPath.replace(/^.*packages\/[^\/]+\//, "");
    if (!workspaceToFiles.has(workspace)) workspaceToFiles.set(workspace, new Set());
    workspaceToFiles.get(workspace).add(relPath);
  }
  const commands = [];
  for (const [workspace, files] of workspaceToFiles.entries()) {
    commands.push(`npm test -w ${workspace} -- ${Array.from(files).join(" ")}`);
  }
  return commands.join(" && ");
}

async function monitor() {
  let runId;
  if (RUN_ID_OVERRIDE) {
    runId = RUN_ID_OVERRIDE;
  } else {
    // Try provided workflow, then ci.yml, then trigger_e2e.yml
    const workflows = WORKFLOW_OVERRIDE ? [WORKFLOW_OVERRIDE] : ['ci.yml', 'trigger_e2e.yml'];
    for (const wf of workflows) {
      const runListOutput = runGh(`run list --workflow "${wf}" --branch "${BRANCH}" --limit 1 --json databaseId,status`);
      if (runListOutput) {
        const runs = JSON.parse(runListOutput);
        if (runs.length > 0 && runs[0].status !== 'completed') {
          runId = runs[0].databaseId;
          console.log(`Monitoring active workflow: ${wf}`);
          break;
        }
      }
    }
    
    // Fallback to latest run of any type if none are in flight
    if (!runId) {
      const runListOutput = runGh(`run list --branch "${BRANCH}" --limit 1 --json databaseId,workflowName`);
      if (runListOutput) {
        const runs = JSON.parse(runListOutput);
        if (runs.length > 0) {
          runId = runs[0].databaseId;
          console.log(`Monitoring latest run: ${runs[0].workflowName} (${runId})`);
        }
      }
    }
  }

  if (!runId) {
    console.log(`No active or recent runs found for branch ${BRANCH}.`);
    process.exit(0);
  }

  console.log(`Target Run ID: ${runId}\n`);

  while (true) {
    const runOutput = runGh(`run view "${runId}" --json databaseId,status,conclusion,workflowName`);
    if (!runOutput) break;
    const run = JSON.parse(runOutput);
    const runStatus = run.status;

    let passed = 0, failed = 0, running = 0, queued = 0, total = 0;
    const jobsOutput = runGh(`run view "${runId}" --json jobs`);
    
    if (jobsOutput) {
      const { jobs } = JSON.parse(jobsOutput);
      total = jobs.length;
      const failedJobs = jobs.filter(j => j.conclusion === 'failure');

      if (failedJobs.length > 0) {
        console.log(`\n❌ CI Failures Detected (${failedJobs.length} jobs failed). Processing...`);
        const fileToTests = new Map();
        for (const job of failedJobs) {
          const failures = fetchFailuresViaApi(job.databaseId);
          if (failures.trim()) {
            failures.split('\n').forEach(line => {
              if (!line.trim()) return;
              const file = extractTestFile(line);
              const filePath = file || (line.toLowerCase().includes('lint') || line.toLowerCase().includes('build') ? 'Build/Lint Error' : 'Unknown File');
              let testName = line;
              if (line.includes(' > ')) {
                 testName = line.split(' > ').slice(1).join(' > ').trim();
              }
              if (!fileToTests.has(filePath)) fileToTests.set(filePath, new Set());
              fileToTests.get(filePath).add(testName);
            });
          } else {
            const step = job.steps?.find(s => s.conclusion === 'failure')?.name || 'unknown';
            const category = step.toLowerCase().includes('lint') ? 'Lint Error' : (step.toLowerCase().includes('build') ? 'Build Error' : 'Job Error');
            if (!fileToTests.has(category)) fileToTests.set(category, new Set());
            fileToTests.get(category).add(`${job.name}: Failed at step "${step}"`);
          }
        }

        console.log('\n--- Structured Failure Report ---');
        for (const [file, tests] of fileToTests.entries()) {
          console.log(`\nCategory/File: ${file}`);
          tests.forEach(t => console.log(`  - ${t}`));
        }

        const testCmd = generateTestCommand(fileToTests);
        if (testCmd) {
          console.log('\n🚀 Run this to verify fixes:');
          console.log(testCmd);
        } else if (Array.from(fileToTests.keys()).some(k => k.includes('Lint'))) {
           console.log('\n🚀 Run this to verify lint fixes:');
           console.log('npm run lint:all');
        }
        console.log('---------------------------------');
        process.exit(1);
      }

      for (const job of jobs) {
        if (job.status === "in_progress") running++;
        else if (job.status === "queued") queued++;
        else if (job.conclusion === "success") passed++;
        else if (job.conclusion === "failure") failed++;
      }
    }

    const completed = passed + failed;
    process.stdout.write(`\r⏳ Monitoring... ${completed}/${total} (${passed} passed, ${failed} failed, ${running} running, ${queued} queued)          `);

    if (runStatus === 'completed') {
      console.log('\n✅ All tests passed!');
      process.exit(0);
    }
    await new Promise(r => setTimeout(r, 15000));
  }
}

monitor().catch(err => {
  console.error('\nMonitor error:', err.message);
  process.exit(1);
});
