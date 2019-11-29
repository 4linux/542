OKD - 3.11
==========

Este **Vagrantfile** cria 4 máquinas, uma com os papeis "master" e "infra", outras duas como "node" e uma outra como storage/ldap.

| Máquina             | Endereço      | Papéis        |
|---------------------|---------------|---------------|
| okd.example.com     | 172.27.11.10  | master, infra |
| node1.example.com   | 172.27.11.20  | node          |
| node2.example.com   | 172.27.11.30  | node          |
| extras.example.com  | 172.27.11.40  | storage, ldap |

Tudo é instalado durante a etapa de provisionamento, isso significa que após o provisionamento o vagrant executa estes dois comandos:

    ansible-playbook /root/openshift-ansible/playbooks/prerequisites.yml
    ansible-playbook /root/openshift-ansible/playbooks/deploy_cluster.yml

O ansible na máquina master está pré-configurado com as chaves ssh para acessar os outros hosts sem problemas.
Durante a etapa de provisionamento, o **inventário** pré-configurado presente em `/files/hosts` é copiado para o master em `/etc/ansible/hosts`. 

NAT
---

Algumas configurações no inventário `/etc/ansible/hosts` e nos arquivos de provisionamento foram adicionadas para evitar problemas com a interface NAT padrão do Virtualbox que o vagrant cria:

 - etcd_ip

Serviços Desabilitados
----------------------

 - openshift_logging_install_logging
 - openshift_enable_olm
 - openshift_enable_service_catalog
 - ansible_service_broker_install
 - template_service_broker_install

Requerimentos
-------------

Do ponto de vista do software, tudo o que precisa é o **VirtualBox**.
Do ponto de vista do hardware, cada máquina utiliza 2 núcleos da cpu, a não ser a **extras**. O master está configurado para utilizar 6GiB de RAM, os nodes 2GiB e a extras 256MiB, então é preciso ao menos 11GiB de memória RAM livre, ou menos caso diminúa a memória de cada vm.
Se a opção **`openshift_metrics_install_metrics`** for desabilitada dentro do inventário, o master poderá ter aproximadamente 2GiB e cada node 1GiB.

Instalação
----------

Levará algum tempo, vá até o diretório clonado e execute:

    vagrant up

Para acessar o **webconsole** é preciso adicionar o seguinte endereço em seu `/etc/hosts`:

	echo '172.27.11.10 okd.example.com' | sudo tee -a /etc/hosts

[https://okd.example.com:8443](https://okd.example.com:8443).
O usuário e senha  são **developer** e **4linux**.

Lembre-se de acessar [https://hawkular-metrics.172-27-11-10.nip.io](https://hawkular-metrics.172-27-11-10.nip.io) e aceitar o certificado auto-assinado.
