import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, deleteDoc, collection, getDocs, updateDoc, Timestamp } from 'firebase/firestore';
import { validProfile } from './profile.js';

/** The profile the real app writes (see test/firestore_profile_fixture_test.dart). */
function realProfile() {
  const revive = (value) => {
    if (Array.isArray(value)) return value.map(revive);
    if (value && typeof value === 'object') {
      if ('__timestamp' in value) return Timestamp.fromDate(new Date(value.__timestamp));
      return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, revive(v)]));
    }
    return value;
  };
  return revive(JSON.parse(readFileSync(new URL('./fixtures/real_profile.json', import.meta.url), 'utf8')));
}

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-sprichst',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});
after(async () => env.cleanup());
beforeEach(async () => env.clearFirestore());

const profileOf = (db, uid) => doc(db, 'users', uid, 'learning', 'profile');
const alice = () => env.authenticatedContext('alice').firestore();
const bob = () => env.authenticatedContext('bob').firestore();
const stranger = () => env.unauthenticatedContext().firestore();

describe('ownership (row level security)', () => {
  test('a learner can create, read, update and delete their own profile', async () => {
    const db = alice();
    await assertSucceeds(setDoc(profileOf(db, 'alice'), validProfile()));
    await assertSucceeds(getDoc(profileOf(db, 'alice')));
    await assertSucceeds(setDoc(profileOf(db, 'alice'), validProfile({ xp: 500 })));
    await assertSucceeds(deleteDoc(profileOf(db, 'alice')));
  });

  test("nobody can read or change another learner's profile", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(profileOf(ctx.firestore(), 'alice'), validProfile());
    });
    const db = bob();
    await assertFails(getDoc(profileOf(db, 'alice')));
    await assertFails(setDoc(profileOf(db, 'alice'), validProfile({ xp: 9999 })));
    await assertFails(deleteDoc(profileOf(db, 'alice')));
  });

  test('signed-out visitors can do nothing', async () => {
    const db = stranger();
    await assertFails(getDoc(profileOf(db, 'alice')));
    await assertFails(setDoc(profileOf(db, 'alice'), validProfile()));
  });

  test('listing other learners data is impossible', async () => {
    const db = bob();
    await assertFails(getDocs(collection(db, 'users', 'alice', 'learning')));
    await assertFails(getDocs(collection(db, 'users')));
  });

  test('a learner can erase the user document during account deletion', async () => {
    await assertSucceeds(deleteDoc(doc(alice(), 'users', 'alice')));
    await assertFails(deleteDoc(doc(bob(), 'users', 'alice')));
  });
});

describe('the document the real app writes', () => {
  test('is accepted, including dates, flashcard states and badges', async () => {
    await assertSucceeds(setDoc(profileOf(alice(), 'alice'), realProfile()));
  });

  test('is accepted when optional parts are absent (a brand-new learner)', async () => {
    const data = realProfile();
    delete data.lastStudyDate;
    delete data.currentLessonId;
    data.flashcards = { newToday: 0, states: {} };
    await assertSucceeds(setDoc(profileOf(alice(), 'alice'), data));
  });

  test('is rejected if tampered with', async () => {
    const data = realProfile();
    data.xp = -1;
    await assertFails(setDoc(profileOf(alice(), 'alice'), data));
    await assertFails(setDoc(profileOf(alice(), 'alice'), { ...realProfile(), role: 'admin' }));
  });
});

describe('input validation in the rules', () => {
  const writes = (data) => setDoc(profileOf(alice(), 'alice'), data);

  test('only the "profile" document may be written under learning/', async () => {
    await assertFails(setDoc(doc(alice(), 'users', 'alice', 'learning', 'other'), validProfile()));
  });

  test('unknown fields are rejected', async () => {
    await assertFails(writes(validProfile({ isAdmin: true })));
  });

  test('missing required fields are rejected', async () => {
    const data = validProfile();
    delete data.xp;
    await assertFails(writes(data));
  });

  test('wrong types are rejected', async () => {
    await assertFails(writes(validProfile({ xp: 'lots' })));
    await assertFails(writes(validProfile({ streak: 1.5 })));
    await assertFails(writes(validProfile({ name: 42 })));
    await assertFails(writes(validProfile({ advancedAiControls: 'yes' })));
    await assertFails(writes(validProfile({ lessonProgress: [] })));
  });

  test('out-of-range values are rejected', async () => {
    await assertFails(writes(validProfile({ xp: -1 })));
    await assertFails(writes(validProfile({ streak: -5 })));
    await assertFails(writes(validProfile({ dailyGoalMinutes: 0 })));
    await assertFails(writes(validProfile({ dailyGoalMinutes: 100000 })));
    await assertFails(writes(validProfile({ glassIntensity: 101 })));
    await assertFails(writes(validProfile({ speechRate: 5000 })));
  });

  test('unknown enum values are rejected', async () => {
    await assertFails(writes(validProfile({ currentLevel: 'z9' })));
    await assertFails(writes(validProfile({ goal: 'hacking' })));
    await assertFails(writes(validProfile({ aiProviderPreference: 'evil' })));
    await assertFails(writes(validProfile({ surfaceStyle: 'neon' })));
  });

  test('oversized text and lists are rejected', async () => {
    await assertFails(writes(validProfile({ name: 'x'.repeat(61) })));
    await assertFails(writes(validProfile({ voice: 'v'.repeat(81) })));
    await assertFails(writes(validProfile({ preferredTopics: Array(31).fill('t') })));
    await assertFails(writes(validProfile({ recentMistakes: Array(51).fill('m') })));
  });

  test('a normal profile with a missing optional field is accepted', async () => {
    const data = validProfile();
    delete data.voicePauseMs;
    delete data.flashcards;
    await assertSucceeds(writes(data));
  });
});

describe('everything else is closed', () => {
  test('shared collections do not exist for clients', async () => {
    const db = alice();
    await assertFails(getDoc(doc(db, 'courses', 'a1')));
    await assertFails(setDoc(doc(db, 'courses', 'a1'), { title: 'x' }));
    await assertFails(setDoc(doc(db, 'admin', 'settings'), { open: true }));
  });

  test('partial updates cannot smuggle in invalid data', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(profileOf(ctx.firestore(), 'alice'), validProfile());
    });
    await assertFails(updateDoc(profileOf(alice(), 'alice'), { xp: -10 }));
    await assertSucceeds(updateDoc(profileOf(alice(), 'alice'), { xp: 10 }));
  });
});
