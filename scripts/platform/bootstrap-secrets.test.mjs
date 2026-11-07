import {test} from 'node:test';
import assert from 'node:assert/strict';
import {bootstrapSecretName, secretEnvironment} from './bootstrap-secrets.mjs';

const dnsSubdomain = /^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$/;
for (const key of ['postgres_admin','mongodb_admin','os','billing','execution']) {
  test(key + ': referencia do Job usa nome aceito pelo Kubernetes', () => {
    const reference = secretEnvironment('DATABASE_PASSWORD',key,'password').valueFrom.secretKeyRef;
    assert.match(reference.name,dnsSubdomain);
    assert.equal(reference.name,bootstrapSecretName(key));
    assert.equal(reference.key,'password');
  });
}
test('nomes administrativos permanecem estaveis e sem underscore', () => {
  assert.equal(bootstrapSecretName('postgres_admin'),'database-postgres-admin');
  assert.equal(bootstrapSecretName('mongodb_admin'),'database-mongodb-admin');
});
test('rejeita chaves que produziriam referencias invalidas', () => {
  for (const key of ['', 'Admin', 'a/b', '_admin', 'admin_', 'a'.repeat(254)])
    assert.throws(() => bootstrapSecretName(key));
});
