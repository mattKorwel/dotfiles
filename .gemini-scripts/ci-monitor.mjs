#!/usr/bin/env node

/**
 * @license
 * Copyright 2026 Google LLC
 * SPDX-License-Identifier: Apache-2.0
 */

import { execSync } from 'node:child_process';

const BRANCH = process.argv[2] || execSync('git branch --show-current').toString().trim();
const RUN_ID_OVERRIDE = process.argv[3];
const WORKFLOW = 'ci.yml';

let REPO;
try {
  const remoteUrl = execSync('git remote get-url origin').toString().trim();
  REPO = remoteUrl.replace(/.*github\.com[\/:]/, '').replace(/\.git$/, '').trim();
} catch (e) {
  REPO = 'google-gemini/gemini-cli';
}

function runGh(args) {
  try {
    return execSync(`gh ${args}`, { stdio: ['ignore', 'pipe', 'ignore'] }).toString();
  } catch (e) {
    return null;
  }
}

function fetchFailuresViaApi(jobId) {
  try {
    const cmd = `gh api repos/${REPO}/actions/jobs/${jobId}/logs | grep -E " FAIL |❌"`;
    return execSync(cmd, { stdio: ['ignore', 'pipe', 'ignore'], maxBuffer: 10 * 1024 * 1024 }).toString();
  } catch (e) {
    return "";
  }
}

function extractTestFile(failureText) {
  // Aggressively strip markdown noise and brackets
  const cleanLine = failureText.replace(/[|#\[\]()]/g, " ").replace(/<[^>]*>/g, " ").trim();
  
  // Try to find a file path ending in .test.ts or .test.js or .test.tsx
  const fileMatch = cleanLine.match(/([\w\/._-]+\.test\.[jt]sx?)/);
  if (fileMatch) {
    return fileMatch[1];
  }
  
  return null;
}

function generateTestCommand(failedFilesMap) {
  const workspaceToFiles = new Map();
  
  for (const [file, info] of failedFilesMap.entries()) {
    if (file === "Job Error" || file === "Unknown File") continue;
    
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
    const runListOutput = runGh(`run list --workflow "${WORKFLOW}" --branch "${BRANCH}" --limit 1 --json databaseId`);
    if (!runListOutput || JSON.parse(runListOutput).length === 0) {
       console.log(`No runs found for branch ${BRANCH}.`);
       process.exit(0);
    }
    runId = JSON.parse(runListOutput)[0].databaseId;
  }

  while (true) {
    const runOutput = runGh(`run view "${runId}" --json databaseId,status,conclusion`);
    if (!runOutput) break;
    const run = JSON.parse(runOutput);
    
    const jobsOutput = runGh(`run view "${runId}" --json jobs`);
    if (jobsOutput) {
      const { jobs } = JSON.parse(jobsOutput);
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
              const filePath = file || 'Unknown File';
              
              // Extract test name part
              let testName = line;
              if (line.includes(' > ')) {
                 testName = line.split(' > ').slice(1).join(' > ').trim();
              }

              if (!fileToTests.has(filePath)) fileToTests.set(filePath, new Set());
              fileToTests.get(filePath).add(testName);
            });
          } else {
            const step = job.steps?.find(s => s.conclusion === 'failure')?.name || 'unknown';
            if (!fileToTests.has('Job Error')) fileToTests.set('Job Error', new Set());
            fileToTests.get('Job Error').add(`${job.name}: Failed at step "${step}"`);
          }
        }

        console.log('\n--- Structured Failure Report ---');
        for (const [file, tests] of fileToTests.entries()) {
          console.log(`\nFile: ${file}`);
          tests.forEach(t => console.log(`  - ${t}`));
        }

        const testCmd = generateTestCommand(fileToTests);
        if (testCmd) {
          console.log('\n🚀 Run this to verify fixes:');
          console.log(testCmd);
        }
        console.log('---------------------------------');
        process.exit(1);
      }
    }

    const counts = JSON.parse(jobsOutput).jobs.reduce((acc, j) => {
      acc[j.status === 'completed' ? (j.conclusion || 'other') : j.status]++;
      return acc;
    }, { success: 0, failure: 0, in_progress: 0, queued: 0, other: 0 });

    process.stdout.write(`\r⏳ Monitoring... ${counts.success} passed, ${counts.failure} failed, ${counts.in_progress} running, ${counts.queued} queued          `);

    if (run.status === 'completed') {
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
