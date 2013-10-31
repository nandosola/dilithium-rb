module UnitOfWork
  module TransactionExceptions
    class Concurrency < Exception; end
  end
  module TransactionRegistryExceptions
    class TransactionNotFound < Exception; end
  end
end
