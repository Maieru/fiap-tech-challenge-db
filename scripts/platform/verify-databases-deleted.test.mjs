import {test} from 'node:test';
import assert from 'node:assert/strict';
import {verifyDatabasesDeleted} from './verify-databases-deleted.mjs';

function inventory(overrides = {}) {
  const calls = [];
  const aws = (...args) => {
    calls.push(args);
    const key = args.slice(0, 2).join(' ');
    if (overrides[key] instanceof Error) throw overrides[key];
    return overrides[key] ?? (args[1] === 'describe-db-instances' ? {DBInstances:[]}
      : args[1] === 'describe-db-clusters' ? {DBClusters:[]} : {Volumes:[]});
  };
  return {aws, calls};
}

test('so aprova remocao quando todos os bancos e volumes da solucao estao ausentes', () => {
  const app = inventory({
    'rds describe-db-instances':{DBInstances:[{DBInstanceIdentifier:'outro-projeto'}]},
    'docdb describe-db-clusters':{DBClusters:[{DBClusterIdentifier:'outro-projeto'}]}
  });
  const messages = [];
  verifyDatabasesDeleted(app.aws, message => messages.push(message));
  assert.equal(messages.length, 1);
  assert.match(messages[0], /Dados do laboratorio excluidos/);
  assert.deepEqual(app.calls.find(args => args[0] === 'ec2'), ['ec2', 'describe-volumes', '--filters',
    'Name=tag:Project,Values=fiap-tech-challenge', 'Name=tag:Component,Values=kafka,mongodb']);
  assert.ok(app.calls.every(args => args[1].startsWith('describe-')));
});

for (const service of ['rds', 'docdb']) {
  for (const kind of ['instances', 'clusters']) {
    test(`bloqueia pipeline se ${service} ${kind} da solucao ainda existir`, () => {
      const property = kind === 'instances' ? 'DBInstances' : 'DBClusters';
      const identifier = kind === 'instances' ? 'DBInstanceIdentifier' : 'DBClusterIdentifier';
      const app = inventory({[`${service} describe-db-${kind}`]:{[property]:[{[identifier]:'fiap-database'}]}});
      assert.throws(() => verifyDatabasesDeleted(app.aws, () => assert.fail('Nao pode anunciar remocao')), /fiap-database/);
    });
  }
}

test('volume MongoDB/Kafka remanescente bloqueia retirada dos componentes Kubernetes', () => {
  const app = inventory({'ec2 describe-volumes':{Volumes:[{VolumeId:'vol-test', State:'deleting'}]}});
  assert.throws(() => verifyDatabasesDeleted(app.aws), /EBS:vol-test/);
});

test('falha de permissao/inventario nao e tratada como ausencia de bancos', () => {
  const app = inventory({'rds describe-db-instances':new Error('AccessDenied')});
  assert.throws(() => verifyDatabasesDeleted(app.aws), /AccessDenied/);
});
