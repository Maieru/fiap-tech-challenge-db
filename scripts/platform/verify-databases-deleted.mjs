import {execFileSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';

const query = (...args) => JSON.parse(execFileSync('aws', [...args, '--output', 'json', '--no-cli-pager'], {encoding:'utf8'}));

export function verifyDatabasesDeleted(aws = query, report = console.log) {
  const remaining = [];
  for (const service of ['rds', 'docdb']) {
    const instances = aws(service, 'describe-db-instances').DBInstances;
    const clusters = aws(service, 'describe-db-clusters').DBClusters;
    remaining.push(...instances.filter(db => db.DBInstanceIdentifier.startsWith('fiap-')).map(db => `${service}:${db.DBInstanceIdentifier}`));
    remaining.push(...clusters.filter(db => db.DBClusterIdentifier.startsWith('fiap-')).map(db => `${service}:${db.DBClusterIdentifier}`));
  }
  const volumes = aws('ec2', 'describe-volumes', '--filters',
    'Name=tag:Project,Values=fiap-tech-challenge', 'Name=tag:Component,Values=kafka,mongodb').Volumes;
  remaining.push(...volumes.map(volume => `EBS:${volume.VolumeId}`));
  if (remaining.length)
    throw new Error('Bancos ou volumes da solucao ainda existem; conferir estados/inventario: ' + remaining.join(', '));
  report('Remocao de RDS/PostgreSQL, DocumentDB e EBS MongoDB/Kafka verificada. Dados do laboratorio excluidos.');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) verifyDatabasesDeleted();
