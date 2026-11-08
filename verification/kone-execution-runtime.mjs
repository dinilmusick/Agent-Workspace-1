import { execFileSync } from 'node:child_process';
import { rmSync } from 'node:fs';

const target = '/tmp/kone-verification';
rmSync(target, { recursive: true, force: true });

const run = (command, args) => {
  console.log('$', command, ...args);
  execFileSync(command, args, { stdio: 'inherit', cwd: '/tmp' });
};

run('git', ['clone', '--branch', 'feature/section-graph-midi-foundation', '--depth', '1', 'https://github.com/dinilmusick/Kone.git', target]);
run('npm', ['install', '--no-audit', '--no-fund']);
run('npm', ['run', 'lint']);
run('npm', ['test]);
run('npm', ['run', 'build']);
run('npm', ['run', 'validate']);
console.log('Kone execution-runtime verification completed.');
