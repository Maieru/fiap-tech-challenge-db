export function bootstrapSecretName(key) {
  if (!/^[a-z0-9]+(?:[_-][a-z0-9]+)*$/.test(key)) throw new Error('Chave de segredo de bootstrap invalida.');
  const name = 'database-' + key.replaceAll('_', '-');
  if (name.length > 253) throw new Error('Nome de segredo de bootstrap excede o limite Kubernetes.');
  return name;
}

export function secretEnvironment(name, key, property) {
  return {name, valueFrom:{secretKeyRef:{name:bootstrapSecretName(key), key:property}}};
}
