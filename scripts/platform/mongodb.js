const uri = 'mongodb://' + encodeURIComponent(process.env.ADMIN_USERNAME) + ':' +
  encodeURIComponent(process.env.ADMIN_PASSWORD) + '@' + process.env.MONGODB_HOST +
  ':27017/admin?authSource=admin&tls=true&tlsCAFile=/mongo-certs/ca.pem&replicaSet=rs0&readPreference=primary&retryWrites=true';
const admin = new Mongo(uri).getDB('admin');
const user = 'fiap_execution';
const options = {pwd: process.env.EXECUTION_PASSWORD, roles: [{role: 'readWrite', db: 'fiap_execution'}]};
if (admin.getUser(user)) admin.updateUser(user, options);
else admin.createUser({user, ...options});
const applicationUri = 'mongodb://' + user + ':' + encodeURIComponent(process.env.EXECUTION_PASSWORD) + '@' +
  process.env.MONGODB_HOST + ':27017/fiap_execution?authSource=admin&tls=true&tlsCAFile=/mongo-certs/ca.pem&replicaSet=rs0';
const application = new Mongo(applicationUri);
if (application.getDB('fiap_execution').runCommand({connectionStatus: 1}).ok !== 1)
  throw new Error('Execution não autenticou no MongoDB.');
try {
  application.getDB('fiap_forbidden').runCommand({find: 'isolation_check', filter: {}});
  throw new Error('Execution deveria ter acesso somente a fiap_execution.');
} catch (error) {
  if (error.code !== 13) throw error;
}
print('Usuario Execution inicializado com acesso somente a fiap_execution.');
