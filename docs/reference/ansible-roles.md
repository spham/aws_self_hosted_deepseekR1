# Documentation des rôles Ansible

Cette page documente le rôle Ansible `ollama` utilisé pour déployer DeepSeek R1 sur l'instance EC2.

## Structure du rôle

```
ansible/roles/ollama/
├── defaults/
│   └── main.yml       # Valeurs par défaut
├── files/
│   ├── ollama.service # Fichier de service systemd
│   └── ui/            # Fichiers de l'interface utilisateur
├── handlers/
│   └── main.yml       # Gestionnaires d'événements
├── tasks/
│   ├── main.yml       # Tâches principales
│   ├── install.yml    # Installation d'Ollama
│   ├── model.yml      # Téléchargement du modèle
│   └── ui.yml         # Configuration de l'interface utilisateur
├── templates/
│   └── config.json.j2 # Template de configuration
└── molecule/
    └── default/       # Tests Molecule
```

## Variables du rôle

| Variable | Type | Description | Valeur par défaut | Obligatoire |
|----------|------|-------------|------------------|------------|
| `ollama_version` | string | Version d'Ollama à installer | `"0.1.27"` | Non |
| `ollama_model` | string | Modèle à télécharger | `"deepseek-r1"` | Non |
| `ollama_model_version` | string | Version du modèle | `"latest"` | Non |
| `ollama_user` | string | Utilisateur pour exécuter Ollama | `"ubuntu"` | Non |
| `ollama_group` | string | Groupe de l'utilisateur | `"ubuntu"` | Non |
| `ollama_service_enabled` | boolean | Activer le service au démarrage | `true` | Non |
| `ollama_ui_port` | number | Port de l'interface utilisateur | `3000` | Non |
| `ollama_ui_repo` | string | Dépôt GitHub de l'UI | `"jakobhoeg/nextjs-ollama-llm-ui"` | Non |
| `ollama_ui_version` | string | Version de l'UI | `"main"` | Non |
| `ollama_api_host` | string | Hôte de l'API Ollama | `"http://localhost:11434"` | Non |
| `ollama_install_dir` | string | Répertoire d'installation | `"/usr/local/bin"` | Non |

## Tâches principales

### Installation d'Ollama

```yaml
- name: Télécharger Ollama
  ansible.builtin.get_url:
    url: "https://github.com/ollama/ollama/releases/download/v{{ ollama_version }}/ollama-linux-amd64"
    dest: "{{ ollama_install_dir }}/ollama"
    mode: '0755'
  become: true

- name: Créer le service systemd
  ansible.builtin.copy:
    src: ollama.service
    dest: /etc/systemd/system/ollama.service
    owner: root
    group: root
    mode: '0644'
  become: true
  notify: restart ollama

- name: Activer et démarrer le service Ollama
  ansible.builtin.systemd:
    name: ollama
    enabled: "{{ ollama_service_enabled }}"
    state: started
    daemon_reload: yes
  become: true
```

### Téléchargement du modèle

```yaml
- name: Télécharger le modèle DeepSeek R1
  ansible.builtin.command:
    cmd: "ollama pull {{ ollama_model }}:{{ ollama_model_version }}"
  register: model_download
  changed_when: "'pulling manifest' in model_download.stderr"
  failed_when: 
    - model_download.rc != 0
    - "'already exists' not in model_download.stderr"
```

### Configuration de l'interface utilisateur

```yaml
- name: Installer Node.js
  ansible.builtin.apt:
    name: 
      - nodejs
      - npm
    state: present
  become: true

- name: Installer PM2
  ansible.builtin.npm:
    name: pm2
    global: yes
  become: true

- name: Cloner le dépôt de l'interface utilisateur
  ansible.builtin.git:
    repo: "https://github.com/{{ ollama_ui_repo }}.git"
    dest: "/home/{{ ollama_user }}/ollama-ui"
    version: "{{ ollama_ui_version }}"
  register: git_clone

- name: Configurer l'API Ollama dans l'interface utilisateur
  ansible.builtin.template:
    src: config.json.j2
    dest: "/home/{{ ollama_user }}/ollama-ui/config.json"
    owner: "{{ ollama_user }}"
    group: "{{ ollama_group }}"
    mode: '0644'

- name: Installer les dépendances de l'interface utilisateur
  ansible.builtin.command:
    cmd: npm install
    chdir: "/home/{{ ollama_user }}/ollama-ui"
  when: git_clone.changed

- name: Construire l'interface utilisateur
  ansible.builtin.command:
    cmd: npm run build
    chdir: "/home/{{ ollama_user }}/ollama-ui"
  when: git_clone.changed

- name: Démarrer l'interface utilisateur avec PM2
  ansible.builtin.command:
    cmd: pm2 start npm --name ollama-ui -- start
    chdir: "/home/{{ ollama_user }}/ollama-ui"
  args:
    creates: "/home/{{ ollama_user }}/.pm2/pids/ollama-ui-0.pid"

- name: Configurer PM2 pour démarrer au boot
  ansible.builtin.command:
    cmd: pm2 save && pm2 startup
  args:
    creates: "/etc/systemd/system/pm2-{{ ollama_user }}.service"
  become: true
```

## Handlers

```yaml
- name: restart ollama
  ansible.builtin.systemd:
    name: ollama
    state: restarted
  become: true

- name: restart ui
  ansible.builtin.command:
    cmd: pm2 restart ollama-ui
  ignore_errors: yes
```

## Exemple d'utilisation

### Playbook de base

```yaml
---
- name: Déployer DeepSeek R1 avec Ollama
  hosts: ollama_instances
  become: true
  
  roles:
    - role: ollama
```

### Playbook avec personnalisation

```yaml
---
- name: Déployer DeepSeek R1 avec Ollama
  hosts: ollama_instances
  become: true
  
  vars:
    ollama_model: "deepseek-r1"
    ollama_model_version: "latest"
    ollama_ui_port: 8080
    ollama_user: "admin"
    ollama_group: "admin"
  
  pre_tasks:
    - name: Créer l'utilisateur admin
      ansible.builtin.user:
        name: admin
        shell: /bin/bash
        groups: sudo
        append: yes
  
  roles:
    - role: ollama
  
  post_tasks:
    - name: Vérifier que Ollama est en cours d'exécution
      ansible.builtin.command:
        cmd: systemctl status ollama
      register: ollama_status
      changed_when: false
      
    - name: Afficher l'état d'Ollama
      ansible.builtin.debug:
        var: ollama_status.stdout_lines
```

## Tests avec Molecule

Le rôle inclut des tests Molecule pour valider son fonctionnement. Pour exécuter les tests :

```bash
cd ansible/roles/ollama
molecule test
```

Les tests vérifient :
- L'installation correcte d'Ollama
- La création et le démarrage du service systemd
- Le téléchargement du modèle
- L'installation et la configuration de l'interface utilisateur
- Le démarrage de l'interface utilisateur avec PM2 