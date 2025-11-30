# Roteiro 3: Paradigma Offline-First com Sincronização Server + Web

**Laboratório de Desenvolvimento de Aplicações Móveis e Distribuídas**  
**Curso de Engenharia de Software - PUC Minas**  
**Professores:** Artur Mol, Cleiton Tavares e Cristiano Neto

---

## Objetivos

- Implementar o paradigma Offline-First em aplicações distribuídas
- Compreender estratégias de sincronização de dados
- Desenvolver mecanismos de detecção e resolução de conflitos
- Implementar cache local e persistência de dados
- Garantir funcionamento da aplicação em ambientes com conectividade intermitente
- Estabelecer base para aplicações móveis resilientes

## Fundamentação Teórica

Segundo Kleppmann (2017), "aplicações offline-first são projetadas para funcionar sem conexão de rede e sincronizar dados quando a conectividade é restaurada" <sup>[1]</sup>. Este paradigma é essencial para aplicações móveis e distribuídas que operam em ambientes com conectividade não confiável.

### Características do Paradigma Offline-First

**Princípios Fundamentais:**
- **Local-First**: Dados são armazenados e manipulados localmente primeiro
- **Sincronização Eventual**: Dados são sincronizados quando conectividade está disponível
- **Resolução de Conflitos**: Estratégias para lidar com modificações concorrentes
- **Experiência Contínua**: Aplicação funciona independente do estado da rede

**Vantagens:**
- Melhor experiência do usuário em redes instáveis
- Redução de latência para operações locais
- Maior resiliência e disponibilidade
- Menor dependência de infraestrutura de rede

**Desafios:**
- Complexidade na sincronização de dados
- Gerenciamento de conflitos
- Consistência eventual vs forte
- Armazenamento local limitado

### Estratégias de Sincronização

Segundo Tanenbaum & Van Steen (2017), existem diferentes abordagens para sincronização <sup>[2]</sup>:

1. **Last-Write-Wins (LWW)**: Última modificação prevalece
2. **Version Vectors**: Rastreamento de versões distribuídas
3. **Operational Transformation**: Transformação de operações concorrentes
4. **CRDTs**: Tipos de dados replicados livres de conflitos

## Cenário do Laboratório

Evolução do sistema de gerenciamento de tarefas implementando:
1. Persistência local com IndexedDB
2. Detecção de estado de conectividade
3. Fila de sincronização para operações offline
4. Mecanismo de resolução de conflitos
5. Sincronização automática e manual
6. Indicadores visuais de estado de sincronização

## Pré-requisitos

- Node.js 16+ e NPM
- Conhecimento dos Roteiros 1 e 2
- Servidor REST do Roteiro 1 ou gRPC do Roteiro 2
- Navegador moderno com suporte a IndexedDB

---

## **PASSO 1: Configuração Inicial do Projeto**

### 1.1 Criar Estrutura do Projeto

```bash
mkdir lab03-offline-first
cd lab03-offline-first
npm init -y
```

### 1.2 Instalar Dependências

```bash
# Dependências principais
npm install express cors body-parser uuid dexie axios

# Dependências de desenvolvimento
npm install --save-dev parcel nodemon concurrently

# Para build do frontend
npm install --save-dev @parcel/transformer-inline-string
```

### 1.3 Estrutura de Diretórios

```
lab03-offline-first/
├── package.json
├── server/
│   ├── server.js              # Servidor backend (simplificado)
│   └── storage.js             # Armazenamento em memória
├── client/
│   ├── index.html             # Interface do usuário
│   ├── styles.css             # Estilos da aplicação
│   └── js/
│       ├── app.js             # Aplicação principal
│       ├── db.js              # Gerenciamento IndexedDB
│       ├── sync.js            # Motor de sincronização
│       ├── conflict.js        # Resolução de conflitos
│       └── ui.js              # Gerenciamento de UI
└── docs/
    └── architecture.md        # Documentação arquitetural
```

---

## **PASSO 2: Servidor Backend Simplificado**

### 2.1 Storage em Memória (`server/storage.js`)

```javascript
const { v4: uuidv4 } = require('uuid');

class ServerStorage {
    constructor() {
        this.tasks = new Map();
        this.lastModified = new Map(); // Rastreamento de modificações
    }

    // Criar tarefa
    createTask(taskData) {
        const task = {
            id: taskData.id || uuidv4(),
            title: taskData.title,
            description: taskData.description || '',
            completed: taskData.completed || false,
            priority: taskData.priority || 'medium',
            userId: taskData.userId || 'user1',
            createdAt: taskData.createdAt || Date.now(),
            updatedAt: Date.now(),
            version: 1 // Controle de versão para conflitos
        };

        this.tasks.set(task.id, task);
        this.lastModified.set(task.id, task.updatedAt);
        return task;
    }

    // Buscar tarefa
    getTask(id) {
        return this.tasks.get(id) || null;
    }

    // Listar todas as tarefas
    listTasks(userId, modifiedSince = null) {
        let tasks = Array.from(this.tasks.values())
            .filter(task => task.userId === userId);

        // Filtrar por modificações desde timestamp (para sync incremental)
        if (modifiedSince) {
            tasks = tasks.filter(task => task.updatedAt > modifiedSince);
        }

        return tasks.sort((a, b) => b.updatedAt - a.updatedAt);
    }

    // Atualizar tarefa com controle de versão
    updateTask(id, updates, clientVersion) {
        const task = this.tasks.get(id);
        if (!task) return { success: false, error: 'NOT_FOUND' };

        // Verificar versão para detectar conflitos
        if (clientVersion && task.version !== clientVersion) {
            return { 
                success: false, 
                error: 'CONFLICT',
                serverTask: task 
            };
        }

        const updatedTask = {
            ...task,
            ...updates,
            id: task.id,
            userId: task.userId,
            createdAt: task.createdAt,
            updatedAt: Date.now(),
            version: task.version + 1
        };

        this.tasks.set(id, updatedTask);
        this.lastModified.set(id, updatedTask.updatedAt);
        
        return { success: true, task: updatedTask };
    }

    // Deletar tarefa
    deleteTask(id, clientVersion) {
        const task = this.tasks.get(id);
        if (!task) return { success: false, error: 'NOT_FOUND' };

        // Verificar versão
        if (clientVersion && task.version !== clientVersion) {
            return { 
                success: false, 
                error: 'CONFLICT',
                serverTask: task 
            };
        }

        this.tasks.delete(id);
        this.lastModified.delete(id);
        return { success: true };
    }

    // Obter timestamp da última modificação (para sync)
    getLastSyncTimestamp(userId) {
        const userTasks = this.listTasks(userId);
        if (userTasks.length === 0) return 0;
        
        return Math.max(...userTasks.map(task => task.updatedAt));
    }

    // Estatísticas
    getStats(userId) {
        const tasks = this.listTasks(userId);
        const completed = tasks.filter(task => task.completed).length;
        
        return {
            total: tasks.length,
            completed,
            pending: tasks.length - completed,
            lastSync: this.getLastSyncTimestamp(userId)
        };
    }
}

module.exports = new ServerStorage();
```

### 2.2 Servidor Express (`server/server.js`)

```javascript
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const storage = require('./storage');

/**
 * Servidor Backend para Aplicação Offline-First
 * 
 * Implementa endpoints REST com suporte a:
 * - Sincronização incremental
 * - Controle de versão
 * - Detecção de conflitos
 * - Operações em lote
 */

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(express.static('client'));

// Logging de requisições
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
    next();
});

// Health check
app.get('/api/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: Date.now(),
        uptime: process.uptime()
    });
});

// Listar tarefas com suporte a sync incremental
app.get('/api/tasks', (req, res) => {
    try {
        const userId = req.query.userId || 'user1';
        const modifiedSince = req.query.modifiedSince ? 
            parseInt(req.query.modifiedSince) : null;

        const tasks = storage.listTasks(userId, modifiedSince);
        const lastSync = storage.getLastSyncTimestamp(userId);

        res.json({
            success: true,
            tasks,
            lastSync,
            serverTime: Date.now()
        });
    } catch (error) {
        console.error('Erro ao listar tarefas:', error);
        res.status(500).json({ 
            success: false, 
            message: 'Erro interno do servidor' 
        });
    }
});

// Buscar tarefa específica
app.get('/api/tasks/:id', (req, res) => {
    try {
        const task = storage.getTask(req.params.id);
        
        if (!task) {
            return res.status(404).json({
                success: false,
                message: 'Tarefa não encontrada'
            });
        }

        res.json({
            success: true,
            task
        });
    } catch (error) {
        console.error('Erro ao buscar tarefa:', error);
        res.status(500).json({ 
            success: false, 
            message: 'Erro interno do servidor' 
        });
    }
});

// Criar tarefa
app.post('/api/tasks', (req, res) => {
    try {
        const { title, description, priority, userId, id, createdAt } = req.body;

        if (!title?.trim()) {
            return res.status(400).json({
                success: false,
                message: 'Título é obrigatório'
            });
        }

        const task = storage.createTask({
            id,          // Permitir cliente definir ID (para sync)
            title: title.trim(),
            description: description?.trim() || '',
            priority: priority || 'medium',
            userId: userId || 'user1',
            createdAt    // Preservar timestamp de criação
        });

        res.status(201).json({
            success: true,
            message: 'Tarefa criada com sucesso',
            task
        });
    } catch (error) {
        console.error('Erro ao criar tarefa:', error);
        res.status(500).json({ 
            success: false, 
            message: 'Erro interno do servidor' 
        });
    }
});

// Atualizar tarefa com controle de versão
app.put('/api/tasks/:id', (req, res) => {
    try {
        const { title, description, completed, priority, version } = req.body;
        
        const result = storage.updateTask(req.params.id, {
            title,
            description,
            completed,
            priority
        }, version);

        if (!result.success) {
            if (result.error === 'NOT_FOUND') {
                return res.status(404).json({
                    success: false,
                    message: 'Tarefa não encontrada'
                });
            }
            
            if (result.error === 'CONFLICT') {
                return res.status(409).json({
                    success: false,
                    message: 'Conflito detectado',
                    conflict: true,
                    serverTask: result.serverTask
                });
            }
        }

        res.json({
            success: true,
            message: 'Tarefa atualizada com sucesso',
            task: result.task
        });
    } catch (error) {
        console.error('Erro ao atualizar tarefa:', error);
        res.status(500).json({ 
            success: false, 
            message: 'Erro interno do servidor' 
        });
    }
});

// Deletar tarefa
app.delete('/api/tasks/:id', (req, res) => {
    try {
        const version = req.query.version ? parseInt(req.query.version) : null;
        const result = storage.deleteTask(req.params.id, version);

        if (!result.success) {
            if (result.error === 'NOT_FOUND') {
                return res.status(404).json({
                    success: false,
                    message: 'Tarefa não encontrada'
                });
            }
            
            if (result.error === 'CONFLICT') {
                return res.status(409).json({
                    success: false,
                    message: 'Conflito detectado',
                    conflict: true,
                    serverTask: result.serverTask
                });
            }
        }

        res.json({
            success: true,
            message: 'Tarefa deletada com sucesso'
        });
    } catch (error) {
        console.error('Erro ao deletar tarefa:', error);
        res.status(500).json({ 
            success: false, 
            message: 'Erro interno do servidor' 
        });
    }
});

// Sincronização em lote
app.post('/api/sync/batch', (req, res) => {
    try {
        const { operations } = req.body;
        const results = [];

        for (const op of operations) {
            let result;
            
            switch (op.type) {
                case 'CREATE':
                    result = {
                        operation: op,
                        task: storage.createTask(op.data)
                    };
                    break;
                    
                case 'UPDATE':
                    result = {
                        operation: op,
                        ...storage.updateTask(op.id, op.data, op.version)
                    };
                    break;
                    
                case 'DELETE':
                    result = {
                        operation: op,
                        ...storage.deleteTask(op.id, op.version)
                    };
                    break;
            }
            
            results.push(result);
        }

        res.json({
            success: true,
            results,
            serverTime: Date.now()
        });
    } catch (error) {
        console.error('Erro na sincronização em lote:', error);
        res.status(500).json({ 
            success: false, 
            message: 'Erro interno do servidor' 
        });
    }
});

// Estatísticas
app.get('/api/stats', (req, res) => {
    try {
        const userId = req.query.userId || 'user1';
        const stats = storage.getStats(userId);
        
        res.json({
            success: true,
            stats
        });
    } catch (error) {
        console.error('Erro ao buscar estatísticas:', error);
        res.status(500).json({ 
            success: false, 
            message: 'Erro interno do servidor' 
        });
    }
});

// Handler de erros global
app.use((error, req, res, next) => {
    console.error('Erro não tratado:', error);
    res.status(500).json({
        success: false,
        message: 'Erro interno do servidor'
    });
});

// Inicialização
app.listen(PORT, () => {
    console.log('🚀 =====================================');
    console.log(`🚀 Servidor Offline-First iniciado`);
    console.log(`🚀 Porta: ${PORT}`);
    console.log(`🚀 URL: http://localhost:${PORT}`);
    console.log('🚀 Recursos:');
    console.log('🚀   - Sync incremental');
    console.log('🚀   - Controle de versão');
    console.log('🚀   - Detecção de conflitos');
    console.log('🚀   - Operações em lote');
    console.log('🚀 =====================================');
});

module.exports = app;
```

---

## **PASSO 3: Gerenciamento de Banco de Dados Local**

### 3.1 IndexedDB Manager (`client/js/db.js`)

```javascript
/**
 * Gerenciamento de IndexedDB para Armazenamento Local
 * 
 * Implementa persistência local usando IndexedDB com:
 * - Armazenamento de tarefas
 * - Fila de sincronização
 * - Rastreamento de conflitos
 * - Metadados de sincronização
 */

class LocalDatabase {
    constructor() {
        this.db = null;
        this.dbName = 'TaskManagerOfflineDB';
        this.version = 1;
    }

    async init() {
        return new Promise((resolve, reject) => {
            const request = indexedDB.open(this.dbName, this.version);

            request.onerror = () => reject(request.error);
            request.onsuccess = () => {
                this.db = request.result;
                console.log('✅ IndexedDB inicializado');
                resolve(this.db);
            };

            request.onupgradeneeded = (event) => {
                const db = event.target.result;

                // Store de tarefas
                if (!db.objectStoreNames.contains('tasks')) {
                    const taskStore = db.createObjectStore('tasks', { keyPath: 'id' });
                    taskStore.createIndex('userId', 'userId', { unique: false });
                    taskStore.createIndex('updatedAt', 'updatedAt', { unique: false });
                    taskStore.createIndex('syncStatus', 'syncStatus', { unique: false });
                }

                // Store de fila de sincronização
                if (!db.objectStoreNames.contains('syncQueue')) {
                    const syncStore = db.createObjectStore('syncQueue', { 
                        keyPath: 'id',
                        autoIncrement: true 
                    });
                    syncStore.createIndex('timestamp', 'timestamp', { unique: false });
                    syncStore.createIndex('status', 'status', { unique: false });
                }

                // Store de metadados
                if (!db.objectStoreNames.contains('metadata')) {
                    db.createObjectStore('metadata', { keyPath: 'key' });
                }

                console.log('📦 Stores do IndexedDB criados');
            };
        });
    }

    // ==================== OPERAÇÕES DE TAREFAS ====================

    async saveTask(task) {
        const transaction = this.db.transaction(['tasks'], 'readwrite');
        const store = transaction.objectStore('tasks');
        
        const taskToSave = {
            ...task,
            syncStatus: task.syncStatus || 'synced',
            localUpdatedAt: Date.now()
        };
        
        return new Promise((resolve, reject) => {
            const request = store.put(taskToSave);
            request.onsuccess = () => resolve(taskToSave);
            request.onerror = () => reject(request.error);
        });
    }

    async getTask(id) {
        const transaction = this.db.transaction(['tasks'], 'readonly');
        const store = transaction.objectStore('tasks');
        
        return new Promise((resolve, reject) => {
            const request = store.get(id);
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error);
        });
    }

    async getAllTasks(userId = 'user1') {
        const transaction = this.db.transaction(['tasks'], 'readonly');
        const store = transaction.objectStore('tasks');
        const index = store.index('userId');
        
        return new Promise((resolve, reject) => {
            const request = index.getAll(userId);
            request.onsuccess = () => {
                const tasks = request.result.sort((a, b) => 
                    (b.updatedAt || 0) - (a.updatedAt || 0)
                );
                resolve(tasks);
            };
            request.onerror = () => reject(request.error);
        });
    }

    async deleteTask(id) {
        const transaction = this.db.transaction(['tasks'], 'readwrite');
        const store = transaction.objectStore('tasks');
        
        return new Promise((resolve, reject) => {
            const request = store.delete(id);
            request.onsuccess = () => resolve(true);
            request.onerror = () => reject(request.error);
        });
    }

    async getUnsyncedTasks() {
        const transaction = this.db.transaction(['tasks'], 'readonly');
        const store = transaction.objectStore('tasks');
        const index = store.index('syncStatus');
        
        return new Promise((resolve, reject) => {
            const request = index.getAll('pending');
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error);
        });
    }

    // ==================== FILA DE SINCRONIZAÇÃO ====================

    async addToSyncQueue(operation) {
        const transaction = this.db.transaction(['syncQueue'], 'readwrite');
        const store = transaction.objectStore('syncQueue');
        
        const queueItem = {
            ...operation,
            timestamp: Date.now(),
            status: 'pending',
            retries: 0
        };
        
        return new Promise((resolve, reject) => {
            const request = store.add(queueItem);
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error);
        });
    }

    async getSyncQueue() {
        const transaction = this.db.transaction(['syncQueue'], 'readonly');
        const store = transaction.objectStore('syncQueue');
        const index = store.index('status');
        
        return new Promise((resolve, reject) => {
            const request = index.getAll('pending');
            request.onsuccess = () => {
                const items = request.result.sort((a, b) => 
                    a.timestamp - b.timestamp
                );
                resolve(items);
            };
            request.onerror = () => reject(request.error);
        });
    }

    async removeFromSyncQueue(id) {
        const transaction = this.db.transaction(['syncQueue'], 'readwrite');
        const store = transaction.objectStore('syncQueue');
        
        return new Promise((resolve, reject) => {
            const request = store.delete(id);
            request.onsuccess = () => resolve(true);
            request.onerror = () => reject(request.error);
        });
    }

    async updateSyncQueueItem(id, updates) {
        const transaction = this.db.transaction(['syncQueue'], 'readwrite');
        const store = transaction.objectStore('syncQueue');
        
        return new Promise((resolve, reject) => {
            const getRequest = store.get(id);
            
            getRequest.onsuccess = () => {
                const item = getRequest.result;
                if (!item) {
                    reject(new Error('Item não encontrado'));
                    return;
                }
                
                const updated = { ...item, ...updates };
                const putRequest = store.put(updated);
                
                putRequest.onsuccess = () => resolve(updated);
                putRequest.onerror = () => reject(putRequest.error);
            };
            
            getRequest.onerror = () => reject(getRequest.error);
        });
    }

    // ==================== METADADOS ====================

    async setMetadata(key, value) {
        const transaction = this.db.transaction(['metadata'], 'readwrite');
        const store = transaction.objectStore('metadata');
        
        return new Promise((resolve, reject) => {
            const request = store.put({ key, value });
            request.onsuccess = () => resolve(value);
            request.onerror = () => reject(request.error);
        });
    }

    async getMetadata(key) {
        const transaction = this.db.transaction(['metadata'], 'readonly');
        const store = transaction.objectStore('metadata');
        
        return new Promise((resolve, reject) => {
            const request = store.get(key);
            request.onsuccess = () => resolve(request.result?.value);
            request.onerror = () => reject(request.error);
        });
    }

    // ==================== UTILIDADES ====================

    async clearAll() {
        const transaction = this.db.transaction(
            ['tasks', 'syncQueue', 'metadata'], 
            'readwrite'
        );
        
        const promises = [
            this.clearStore(transaction.objectStore('tasks')),
            this.clearStore(transaction.objectStore('syncQueue')),
            this.clearStore(transaction.objectStore('metadata'))
        ];
        
        return Promise.all(promises);
    }

    clearStore(store) {
        return new Promise((resolve, reject) => {
            const request = store.clear();
            request.onsuccess = () => resolve(true);
            request.onerror = () => reject(request.error);
        });
    }

    async getStats() {
        const [tasks, queue] = await Promise.all([
            this.getAllTasks(),
            this.getSyncQueue()
        ]);
        
        const unsynced = tasks.filter(t => t.syncStatus === 'pending').length;
        
        return {
            totalTasks: tasks.length,
            unsyncedTasks: unsynced,
            queuedOperations: queue.length,
            lastSync: await this.getMetadata('lastSyncTimestamp')
        };
    }
}

// Exportar instância única
const localDB = new LocalDatabase();
```

---

## **PASSO 4: Motor de Sincronização**

### 4.1 Sync Engine (`client/js/sync.js`)

```javascript
/**
 * Motor de Sincronização Offline-First
 * 
 * Implementa estratégias de sincronização incluindo:
 * - Sync incremental baseado em timestamp
 * - Detecção automática de conectividade
 * - Fila de operações offline
 * - Retry com backoff exponencial
 * - Resolução de conflitos
 */

class SyncEngine {
    constructor(localDB, apiBaseUrl = 'http://localhost:3000/api') {
        this.localDB = localDB;
        this.apiBaseUrl = apiBaseUrl;
        this.userId = 'user1';
        this.isSyncing = false;
        this.isOnline = navigator.onLine;
        this.syncInterval = null;
        this.listeners = new Set();
        
        this.setupConnectivityListeners();
    }

    // ==================== GERENCIAMENTO DE CONECTIVIDADE ====================

    setupConnectivityListeners() {
        window.addEventListener('online', () => {
            console.log('🟢 Conexão restaurada');
            this.isOnline = true;
            this.notifyListeners({ type: 'online' });
            this.sync(); // Sincronizar automaticamente ao voltar online
        });

        window.addEventListener('offline', () => {
            console.log('🔴 Conexão perdida');
            this.isOnline = false;
            this.notifyListeners({ type: 'offline' });
        });
    }

    async checkConnectivity() {
        if (!navigator.onLine) {
            this.isOnline = false;
            return false;
        }

        try {
            const response = await fetch(`${this.apiBaseUrl}/health`, {
                method: 'HEAD',
                cache: 'no-cache'
            });
            this.isOnline = response.ok;
            return this.isOnline;
        } catch (error) {
            this.isOnline = false;
            return false;
        }
    }

    // ==================== SINCRONIZAÇÃO PRINCIPAL ====================

    async sync() {
        if (this.isSyncing) {
            console.log('⏳ Sincronização já em andamento');
            return { success: false, message: 'Sync já em andamento' };
        }

        const isOnline = await this.checkConnectivity();
        if (!isOnline) {
            console.log('📴 Sem conectividade - operações serão enfileiradas');
            return { success: false, message: 'Sem conectividade' };
        }

        this.isSyncing = true;
        this.notifyListeners({ type: 'syncStart' });

        try {
            console.log('🔄 Iniciando sincronização...');
            
            // 1. Processar fila de operações pendentes
            await this.processSyncQueue();
            
            // 2. Pull: Buscar atualizações do servidor
            await this.pullFromServer();
            
            // 3. Atualizar timestamp de última sincronização
            await this.localDB.setMetadata('lastSyncTimestamp', Date.now());
            
            console.log('✅ Sincronização concluída com sucesso');
            this.notifyListeners({ 
                type: 'syncComplete', 
                success: true 
            });
            
            return { success: true, message: 'Sincronização concluída' };
            
        } catch (error) {
            console.error('❌ Erro na sincronização:', error);
            this.notifyListeners({ 
                type: 'syncError', 
                error: error.message 
            });
            
            return { success: false, message: error.message };
            
        } finally {
            this.isSyncing = false;
        }
    }

    async processSyncQueue() {
        const queue = await this.localDB.getSyncQueue();
        console.log(`📤 Processando ${queue.length} operações pendentes`);

        for (const item of queue) {
            try {
                await this.processQueueItem(item);
                await this.localDB.removeFromSyncQueue(item.id);
            } catch (error) {
                console.error(`Erro ao processar item ${item.id}:`, error);
                
                // Incrementar contador de tentativas
                await this.localDB.updateSyncQueueItem(item.id, {
                    retries: (item.retries || 0) + 1,
                    lastError: error.message
                });
                
                // Se excedeu máximo de tentativas, marcar como failed
                if ((item.retries || 0) >= 3) {
                    await this.localDB.updateSyncQueueItem(item.id, {
                        status: 'failed'
                    });
                }
            }
        }
    }

    async processQueueItem(item) {
        const { type, data, taskId } = item;
        
        switch (type) {
            case 'CREATE':
                return await this.pushCreate(data);
                
            case 'UPDATE':
                return await this.pushUpdate(taskId, data);
                
            case 'DELETE':
                return await this.pushDelete(taskId, data.version);
                
            default:
                throw new Error(`Tipo de operação desconhecido: ${type}`);
        }
    }

    // ==================== PUSH (Cliente → Servidor) ====================

    async pushCreate(task) {
        const response = await fetch(`${this.apiBaseUrl}/tasks`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                ...task,
                userId: this.userId
            })
        });

        if (!response.ok) {
            throw new Error(`Erro ao criar tarefa: ${response.statusText}`);
        }

        const result = await response.json();
        
        // Atualizar tarefa local com dados do servidor
        await this.localDB.saveTask({
            ...result.task,
            syncStatus: 'synced'
        });

        return result;
    }

    async pushUpdate(taskId, updates) {
        const response = await fetch(`${this.apiBaseUrl}/tasks/${taskId}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(updates)
        });

        if (response.status === 409) {
            // Conflito detectado
            const result = await response.json();
            console.warn('⚠️ Conflito detectado ao atualizar tarefa');
            
            // Notificar sobre conflito
            this.notifyListeners({
                type: 'conflict',
                localTask: updates,
                serverTask: result.serverTask
            });
            
            throw new Error('CONFLICT');
        }

        if (!response.ok) {
            throw new Error(`Erro ao atualizar tarefa: ${response.statusText}`);
        }

        const result = await response.json();
        
        // Atualizar tarefa local
        await this.localDB.saveTask({
            ...result.task,
            syncStatus: 'synced'
        });

        return result;
    }

    async pushDelete(taskId, version) {
        const url = `${this.apiBaseUrl}/tasks/${taskId}${version ? `?version=${version}` : ''}`;
        
        const response = await fetch(url, {
            method: 'DELETE'
        });

        if (response.status === 409) {
            const result = await response.json();
            console.warn('⚠️ Conflito detectado ao deletar tarefa');
            
            this.notifyListeners({
                type: 'conflict',
                operation: 'delete',
                taskId,
                serverTask: result.serverTask
            });
            
            throw new Error('CONFLICT');
        }

        if (!response.ok && response.status !== 404) {
            throw new Error(`Erro ao deletar tarefa: ${response.statusText}`);
        }

        // Remover da base local
        await this.localDB.deleteTask(taskId);
        
        return { success: true };
    }

    // ==================== PULL (Servidor → Cliente) ====================

    async pullFromServer() {
        const lastSync = await this.localDB.getMetadata('lastSyncTimestamp') || 0;
        
        // Buscar apenas tarefas modificadas desde última sync (incremental)
        const url = `${this.apiBaseUrl}/tasks?userId=${this.userId}&modifiedSince=${lastSync}`;
        
        const response = await fetch(url);
        
        if (!response.ok) {
            throw new Error(`Erro ao buscar tarefas: ${response.statusText}`);
        }

        const result = await response.json();
        const serverTasks = result.tasks || [];
        
        console.log(`📥 Recebidas ${serverTasks.length} tarefas do servidor`);

        // Atualizar tarefas locais
        for (const serverTask of serverTasks) {
            const localTask = await this.localDB.getTask(serverTask.id);
            
            if (!localTask) {
                // Nova tarefa do servidor
                await this.localDB.saveTask({
                    ...serverTask,
                    syncStatus: 'synced'
                });
            } else if (localTask.syncStatus === 'synced') {
                // Atualização do servidor (sem modificações locais)
                await this.localDB.saveTask({
                    ...serverTask,
                    syncStatus: 'synced'
                });
            } else {
                // Possível conflito (tarefa modificada localmente e no servidor)
                console.warn('⚠️ Possível conflito detectado:', serverTask.id);
                
                this.notifyListeners({
                    type: 'conflict',
                    localTask,
                    serverTask
                });
            }
        }

        this.notifyListeners({ type: 'pullComplete', count: serverTasks.length });
    }

    // ==================== SINCRONIZAÇÃO AUTOMÁTICA ====================

    startAutoSync(intervalMs = 30000) {
        if (this.syncInterval) {
            clearInterval(this.syncInterval);
        }

        this.syncInterval = setInterval(() => {
            if (this.isOnline && !this.isSyncing) {
                console.log('🔄 Auto-sync iniciado');
                this.sync();
            }
        }, intervalMs);

        console.log(`✅ Auto-sync configurado (intervalo: ${intervalMs}ms)`);
    }

    stopAutoSync() {
        if (this.syncInterval) {
            clearInterval(this.syncInterval);
            this.syncInterval = null;
            console.log('⏸️ Auto-sync pausado');
        }
    }

    // ==================== LISTENERS ====================

    addListener(callback) {
        this.listeners.add(callback);
        return () => this.listeners.delete(callback);
    }

    notifyListeners(event) {
        this.listeners.forEach(callback => {
            try {
                callback(event);
            } catch (error) {
                console.error('Erro ao notificar listener:', error);
            }
        });
    }

    // ==================== UTILITÁRIOS ====================

    async getStatus() {
        const stats = await this.localDB.getStats();
        const lastSync = await this.localDB.getMetadata('lastSyncTimestamp');
        
        return {
            isOnline: this.isOnline,
            isSyncing: this.isSyncing,
            lastSync: lastSync ? new Date(lastSync).toISOString() : null,
            ...stats
        };
    }
}
```

---

## **PASSO 5: Resolução de Conflitos**

### 5.1 Conflict Resolver (`client/js/conflict.js`)

```javascript
/**
 * Sistema de Resolução de Conflitos
 * 
 * Implementa estratégias para resolver conflitos de sincronização:
 * - Last-Write-Wins (LWW)
 * - Manual Resolution
 * - Field-level merge
 */

class ConflictResolver {
    constructor() {
        this.strategy = 'manual'; // 'lww', 'manual', 'merge'
        this.pendingConflicts = [];
    }

    /**
     * Detectar se existe conflito entre versões local e servidor
     */
    detectConflict(localTask, serverTask) {
        // Se versões são diferentes e ambas foram modificadas
        if (localTask.version !== serverTask.version) {
            return {
                hasConflict: true,
                reason: 'VERSION_MISMATCH',
                localTask,
                serverTask
            };
        }

        // Se timestamps de atualização são muito diferentes
        const timeDiff = Math.abs(
            (localTask.updatedAt || 0) - (serverTask.updatedAt || 0)
        );
        
        if (timeDiff > 1000) { // Mais de 1 segundo de diferença
            return {
                hasConflict: true,
                reason: 'TIMESTAMP_MISMATCH',
                localTask,
                serverTask
            };
        }

        return { hasConflict: false };
    }

    /**
     * Resolver conflito usando Last-Write-Wins
     */
    resolveLastWriteWins(localTask, serverTask) {
        const localTime = localTask.updatedAt || localTask.localUpdatedAt || 0;
        const serverTime = serverTask.updatedAt || 0;

        if (localTime > serverTime) {
            console.log('🏆 LWW: Versão local vence');
            return {
                resolution: 'local',
                task: localTask,
                reason: 'Local modification is newer'
            };
        } else {
            console.log('🏆 LWW: Versão servidor vence');
            return {
                resolution: 'server',
                task: serverTask,
                reason: 'Server modification is newer'
            };
        }
    }

    /**
     * Merge inteligente de campos
     */
    mergeFields(localTask, serverTask) {
        const merged = { ...serverTask }; // Começar com versão do servidor
        
        // Prioridades de merge
        const priorities = {
            title: 'local',        // Título: preferir local
            description: 'local',  // Descrição: preferir local
            completed: 'server',   // Status: preferir servidor
            priority: 'local'      // Prioridade: preferir local
        };

        for (const [field, preference] of Object.entries(priorities)) {
            if (localTask[field] !== serverTask[field]) {
                console.log(`🔀 Conflito no campo "${field}"`);
                
                if (preference === 'local') {
                    merged[field] = localTask[field];
                    console.log(`  → Usando valor local: ${localTask[field]}`);
                } else {
                    merged[field] = serverTask[field];
                    console.log(`  → Usando valor servidor: ${serverTask[field]}`);
                }
            }
        }

        return {
            resolution: 'merged',
            task: merged,
            reason: 'Field-level merge applied'
        };
    }

    /**
     * Adicionar conflito à lista de pendentes
     */
    addPendingConflict(conflict) {
        this.pendingConflicts.push({
            ...conflict,
            timestamp: Date.now(),
            id: `conflict-${Date.now()}-${Math.random()}`
        });
    }

    /**
     * Obter conflitos pendentes
     */
    getPendingConflicts() {
        return this.pendingConflicts;
    }

    /**
     * Resolver conflito manualmente
     */
    resolveManually(conflictId, choice) {
        const index = this.pendingConflicts.findIndex(c => c.id === conflictId);
        
        if (index === -1) {
            throw new Error('Conflito não encontrado');
        }

        const conflict = this.pendingConflicts[index];
        let resolution;

        switch (choice) {
            case 'local':
                resolution = {
                    resolution: 'local',
                    task: conflict.localTask,
                    reason: 'User chose local version'
                };
                break;
                
            case 'server':
                resolution = {
                    resolution: 'server',
                    task: conflict.serverTask,
                    reason: 'User chose server version'
                };
                break;
                
            case 'merge':
                resolution = this.mergeFields(conflict.localTask, conflict.serverTask);
                break;
                
            default:
                throw new Error('Escolha inválida');
        }

        // Remover conflito da lista de pendentes
        this.pendingConflicts.splice(index, 1);
        
        return resolution;
    }

    /**
     * Resolver todos os conflitos pendentes automaticamente
     */
    resolveAllAuto() {
        const resolutions = [];

        for (const conflict of this.pendingConflicts) {
            let resolution;

            switch (this.strategy) {
                case 'lww':
                    resolution = this.resolveLastWriteWins(
                        conflict.localTask,
                        conflict.serverTask
                    );
                    break;
                    
                case 'merge':
                    resolution = this.mergeFields(
                        conflict.localTask,
                        conflict.serverTask
                    );
                    break;
                    
                default:
                    // Manter para resolução manual
                    continue;
            }

            resolutions.push({
                conflictId: conflict.id,
                ...resolution
            });
        }

        // Limpar conflitos resolvidos
        if (this.strategy !== 'manual') {
            this.pendingConflicts = [];
        }

        return resolutions;
    }

    /**
     * Configurar estratégia de resolução
     */
    setStrategy(strategy) {
        if (!['lww', 'manual', 'merge'].includes(strategy)) {
            throw new Error('Estratégia inválida');
        }
        
        this.strategy = strategy;
        console.log(`✅ Estratégia de resolução definida: ${strategy}`);
    }

    /**
     * Limpar conflitos resolvidos
     */
    clearResolved() {
        this.pendingConflicts = [];
    }
}
```
