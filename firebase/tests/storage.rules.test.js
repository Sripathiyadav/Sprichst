import { after, before, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { assertFails, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { ref, uploadString, getBytes } from 'firebase/storage';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-sprichst',
    storage: { rules: readFileSync(new URL('../storage.rules', import.meta.url), 'utf8') },
  });
});
after(async () => env.cleanup());

test('Storage is closed to every client', async () => {
  const storage = env.authenticatedContext('alice').storage();
  await assertFails(uploadString(ref(storage, 'users/alice/a.txt'), 'hello'));
  await assertFails(getBytes(ref(storage, 'users/alice/a.txt')));
  await assertFails(uploadString(ref(env.unauthenticatedContext().storage(), 'x.txt'), 'hi'));
});
