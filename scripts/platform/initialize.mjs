import {execFileSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
const namespace = 'fiap-data-bootstrap';
const k = (args, input) => execFileSync('kubectl', ['-n', namespace, ...args], {encoding:'utf8', input});
const env = (name, secret, key) => ({name,valueFrom:{secretKeyRef:{name:secret,key}}});
const certificate = {name:'ca',configMap:{name:'aws-database-ca'}};
const mount = {name:'ca',mountPath:'/certs',readOnly:true};
const mongoCertificate = {name:'mongo-ca',configMap:{name:'mongodb-ca'}};
const mongoMount = {name:'mongo-ca',mountPath:'/mongo-certs',readOnly:true};
const runId = (process.env.GITHUB_RUN_ID + '-' + process.env.GITHUB_RUN_ATTEMPT).replace(/[^0-9-]/g,'');
if (!/^\d+-\d+$/.test(runId)) throw new Error('Run id invalido.');
const config = {apiVersion:'v1',kind:'ConfigMap',metadata:{name:'database-bootstrap-scripts',namespace},data:{}};
for (const name of ['postgres.sql','postgres.sh','mongodb.js']) config.data[name]=readFileSync(new URL(name,import.meta.url),'utf8');
k(['apply','-f','-'],JSON.stringify(config));
for (const name of ['postgres_admin','mongodb_admin','os','billing','execution'])
  k(['wait','externalsecret/database-'+name,'--for=condition=Ready','--timeout=180s']);
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function job(component, container, extraVolumes=[]) {
  const name='database-'+component+'-'+runId;
  const spec={apiVersion:'batch/v1',kind:'Job',metadata:{name,namespace},spec:{backoffLimit:0,activeDeadlineSeconds:600,template:{spec:{
    restartPolicy:'Never',automountServiceAccountToken:false,containers:[{...container,volumeMounts:[mount,mongoMount,...(container.volumeMounts||[])],
      resources:{requests:{cpu:'100m',memory:'256Mi'},limits:{cpu:'1',memory:'512Mi'}}}],volumes:[certificate,mongoCertificate,...extraVolumes]
  }}}};
  k(['delete','job',name,'--ignore-not-found=true','--wait=true']);
  k(['create','-f','-'],JSON.stringify(spec));
  let completed=false;
  for(let attempt=0;attempt<130;attempt++) {
    const status=JSON.parse(k(['get','job',name,'-o','json'])).status;
    if(status?.conditions?.some(c=>c.type==='Failed'&&c.status==='True')) break;
    if(status?.succeeded===1){completed=true;break;}
    await sleep(5000);
  }
  try { process.stdout.write(k(['logs','job/'+name,'--all-containers=true'])); } catch { /* Job status below remains authoritative. */ }
  if(!completed) throw new Error('Job falhou ou excedeu o prazo: '+name);
  k(['delete','job',name,'--wait=true']);
}
const scriptMount={name:'scripts',mountPath:'/scripts',readOnly:true};
const scriptVolume={name:'scripts',configMap:{name:config.metadata.name}};
await job('postgres', {name:'initialize',image:'postgres:18.3@sha256:7e32e9833a6fb1c92c32552794cb6ed569d51b445a54907d35fc112ef39684db',
  command:['/bin/sh','/scripts/postgres.sh'],volumeMounts:[scriptMount],env:[
    env('PGHOST','database-postgres_admin','host'),env('PGUSER','database-postgres_admin','username'),env('PGPASSWORD','database-postgres_admin','password'),
    {name:'PGDATABASE',value:'postgres'},{name:'PGSSLMODE',value:'verify-full'},{name:'PGSSLROOTCERT',value:'/certs/global-bundle.pem'},
    env('OS_PASSWORD','database-os','password'),env('BILLING_PASSWORD','database-billing','password')
  ]},[scriptVolume]);
await job('mongodb', {name:'initialize',image:'mongo:8.0@sha256:b9924c330a8bbc5800fe9c69f04a84e221eca7b28fd049a0354147d9908fa142',
  command:['mongosh','--nodb','--quiet','/scripts/mongodb.js'],volumeMounts:[scriptMount],env:[
    env('ADMIN_USERNAME','database-mongodb_admin','username'),env('ADMIN_PASSWORD','database-mongodb_admin','password'),
    env('MONGODB_HOST','database-mongodb_admin','host'),env('EXECUTION_PASSWORD','database-execution','password')
  ]},[scriptVolume]);
const image=process.env.EXECUTION_IMAGE;
if(!/^\d{12}\.dkr\.ecr\.us-east-1\.amazonaws\.com\/fiap-ecr-execution-repository@sha256:[a-f0-9]{64}$/.test(image||'')) throw new Error('Imagem Execution invalida.');
await job('compatibility', {name:'compatibility',image,args:['--verify-persistence'],env:[
  env('Mongo__ConnectionString','database-mongodb_admin','Mongo__ConnectionString'),
  {name:'Mongo__DatabaseName',value:'fiap_compat_'+runId.replaceAll('-','_')},
  {name:'Mongo__UseDocumentDb',value:'false'},{name:'Mongo__CaCertificatePath',value:'/mongo-certs/ca.pem'}
]});
