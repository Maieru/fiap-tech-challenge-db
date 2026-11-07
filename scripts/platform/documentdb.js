const uri = 'mongodb://' + encodeURIComponent(process.env.ADMIN_USERNAME) + ':' +
  encodeURIComponent(process.env.ADMIN_PASSWORD) + '@' + process.env.DOCUMENTDB_HOST +
  ':27017/admin?authSource=admin&tls=true&tlsCAFile=/certs/global-bundle.pem&replicaSet=rs0&readPreference=primary&retryWrites=false';
const admin = new Mongo(uri).getDB('admin');
const user = 'fiap_execution';
const options = {pwd: process.env.EXECUTION_PASSWORD, roles: [{role: 'readWrite', db: 'fiap_execution'}]};
if (admin.getUser(user)) admin.updateUser(user, options);
else admin.createUser({user, ...options});
print('Usuario Execution inicializado com acesso somente a fiap_execution.');
