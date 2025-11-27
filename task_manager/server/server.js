const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const path = require('path');
const storage = require('./storage');

/**
 * Servidor Backend para Aplicação Offline-First
 * Endpoints REST com suporte a:
 * - Sync incremental
 * - Controle de versão
 * - Detecção de conflitos
 * - Operações em lote
 */

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(express.static(path.join(__dirname, 'client')));

// Logging simples
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
  next();
});

// Health check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: Date.now(),
    uptime: process.uptime(),
  });
});

// Listar tarefas com sync incremental
app.get('/api/tasks', (req, res) => {
  try {
    const userId = req.query.userId || 'user1';
    const modifiedSince = req.query.modifiedSince ? parseInt(req.query.modifiedSince, 10) : null;

    const tasks = storage.listTasks(userId, modifiedSince);
    const lastSync = storage.getLastSyncTimestamp(userId);

    res.json({
      success: true,
      tasks,
      lastSync,
      serverTime: Date.now(),
    });
  } catch (error) {
    console.error('Erro ao listar tarefas:', error);
    res.status(500).json({ success: false, message: 'Erro interno do servidor' });
  }
});

// Buscar tarefa
app.get('/api/tasks/:id', (req, res) => {
  try {
    const task = storage.getTask(req.params.id);
    if (!task) {
      return res.status(404).json({ success: false, message: 'Tarefa não encontrada' });
    }
    res.json({ success: true, task });
  } catch (error) {
    console.error('Erro ao buscar tarefa:', error);
    res.status(500).json({ success: false, message: 'Erro interno do servidor' });
  }
});

// Criar tarefa
app.post('/api/tasks', (req, res) => {
  try {
    const { title, description, priority, userId, id, createdAt } = req.body;

    if (!title?.trim()) {
      return res.status(400).json({ success: false, message: 'Título é obrigatório' });
    }

    const task = storage.createTask({
      id,
      title: title.trim(),
      description: description?.trim() || '',
      priority: priority || 'medium',
      userId: userId || 'user1',
      createdAt,
    });

    res.status(201).json({ success: true, message: 'Tarefa criada com sucesso', task });
  } catch (error) {
    console.error('Erro ao criar tarefa:', error);
    res.status(500).json({ success: false, message: 'Erro interno do servidor' });
  }
});

// Atualizar tarefa
app.put('/api/tasks/:id', (req, res) => {
  try {
    const { title, description, completed, priority, version } = req.body;

    const result = storage.updateTask(
      req.params.id,
      { title, description, completed, priority },
      version,
    );

    if (!result.success) {
      if (result.error === 'NOT_FOUND') {
        return res.status(404).json({ success: false, message: 'Tarefa não encontrada' });
      }
      if (result.error === 'CONFLICT') {
        return res.status(409).json({
          success: false,
          message: 'Conflito detectado',
          conflict: true,
          serverTask: result.serverTask,
        });
      }
    }

    res.json({ success: true, message: 'Tarefa atualizada com sucesso', task: result.task });
  } catch (error) {
    console.error('Erro ao atualizar tarefa:', error);
    res.status(500).json({ success: false, message: 'Erro interno do servidor' });
  }
});

// Deletar tarefa
app.delete('/api/tasks/:id', (req, res) => {
  try {
    const version = req.query.version ? parseInt(req.query.version, 10) : null;
    const result = storage.deleteTask(req.params.id, version);

    if (!result.success) {
      if (result.error === 'NOT_FOUND') {
        return res.status(404).json({ success: false, message: 'Tarefa não encontrada' });
      }
      if (result.error === 'CONFLICT') {
        return res.status(409).json({
          success: false,
          message: 'Conflito detectado',
          conflict: true,
          serverTask: result.serverTask,
        });
      }
    }

    res.json({ success: true, message: 'Tarefa deletada com sucesso' });
  } catch (error) {
    console.error('Erro ao deletar tarefa:', error);
    res.status(500).json({ success: false, message: 'Erro interno do servidor' });
  }
});

// Sincronização em lote
app.post('/api/sync/batch', (req, res) => {
  try {
    const { operations } = req.body;
    const results = [];

    for (const op of operations || []) {
      let result;
      switch (op.type) {
        case 'CREATE':
          result = { operation: op, task: storage.createTask(op.data) };
          break;
        case 'UPDATE':
          result = { operation: op, ...storage.updateTask(op.id, op.data, op.version) };
          break;
        case 'DELETE':
          result = { operation: op, ...storage.deleteTask(op.id, op.version) };
          break;
        default:
          result = { operation: op, success: false, error: 'UNKNOWN_OP' };
      }
      results.push(result);
    }

    res.json({ success: true, results, serverTime: Date.now() });
  } catch (error) {
    console.error('Erro na sincronização em lote:', error);
    res.status(500).json({ success: false, message: 'Erro interno do servidor' });
  }
});

// Estatísticas
app.get('/api/stats', (req, res) => {
  try {
    const userId = req.query.userId || 'user1';
    const stats = storage.getStats(userId);
    res.json({ success: true, stats });
  } catch (error) {
    console.error('Erro ao buscar estatísticas:', error);
    res.status(500).json({ success: false, message: 'Erro interno do servidor' });
  }
});

// Handler de erros global
app.use((error, req, res, next) => {
  console.error('Erro não tratado:', error);
  res.status(500).json({ success: false, message: 'Erro interno do servidor' });
});

app.listen(PORT, () => {
  console.log('🚀 =====================================');
  console.log('🚀 Servidor Offline-First iniciado');
  console.log(`🚀 Porta: ${PORT}`);
  console.log(`🚀 URL: http://localhost:${PORT}`);
  console.log('🚀 Recursos:');
  console.log('🚀   - Sync incremental');
  console.log('🚀   - Controle de versão');
  console.log('🚀   - Detecção de conflitos');
  console.log('🚀   - Operações em lote');
  console.log('🚀 =====================================');
});
