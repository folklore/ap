require 'benchmark'
COUNT = 10000000 # кол-во рабочих

# от сюда ...

class Employee
  attr_accessor :age, :salary, :height, :weight

  def initialize
    @age = rand(100)
    @height = rand(200)
    @weight = rand(200)
    @salary = 0.1 * rand(10000000)
  end
end

@staff = [ ]

for id in 1 .. COUNT
  @staff << Employee.new
end

# ... до сюда, без комментариев.

# Условия поиска для полей экземпляров класса Employee
# (для максимального и(или) минимального значения поля допускается nil)
input = { age:    { min: rand(25),
                    max: 75+rand(25) },
          height: { min: nil,
                    max: 150 + rand(50) },
          weight: { min: rand(50),
                    max: nil },
          salary: { min: 0.1 * rand(2500000),
                    max: 750000 + 0.1 * rand(2500000) } }

# Функция поиска в массиве staff, по одному из показателей поля экземпляра класса Employee
def search(array, value, limit)

  mid = 0
  low = 0
  high = array.length - 1

  # Если условие поиска не отсутсвует.
  if not value.nil?
    # Интерполирующий поиск
    while array[low] < value and array[high] > value

      # Если судить по описанию, в найденых мною источников,
      # в эту строку закладывается следующее ...
      # интерполирующий поиск производит оценку новой области поиска
      # по расстоянию между ключом поиска и текущим значением элемента
      mid = low + ( (value-array[low])*(high-low) ) / ( array[high]-array[low] )

      # Eсли значение элемента mid меньше, то смещаем нижнюю границу
      if array[mid] < value
        low = mid+1
      # Eсли значение элемента mid больше, то смещаем верхнюю границу
      elsif array[mid] > value
        high = mid-1;
      # Если равны, то ...
      else

        #
        # Следующий участок кода добавлен потому, что любой из поисков,
        # хоть это бинарный или интерполирующий, имеет недостаток, связанный
        # с тем, что идя от центра массива, или предположительного места
        # нахождения искомого значения, поиск завершается, как только дойдёт
        # до этого самого искомого значения, и всё бы было хорошо, если бы не
        # ситуация, когда могут быть дубликаты в отсортированном массиве.

        # puts "Первый встречный #{limit} индекс #{mid}"

        i = limit == :min ? -1 : 1
        while array[mid] == array[mid+i]
          mid += i
        end

        # puts "Правильный #{limit} индекс #{mid}"

        # Конец.
        #

        break

      end
    end
  # Если отсутствует минимальное условие
  elsif limit == :min
    mid = low
  # Если отсутствует максимальное условие
  else
    mid = high
  end

  return mid.to_i
end

result = [ ]

# Массив потоков
threads = [ ]

puts "Всего экземпляров (всего рабочих) #{COUNT}"

Benchmark.bm { |bench|
  bench.report("Весь поиск") {
    [:age, :height, :weight, :salary].each { |attribute|
      threads << Thread.new {
        # Каждый потока сортирует штат
        # по подотчётному ему атрибуту
        staff = @staff.sort_by{ |e| e.send(attribute) }

        # Массив подпотоков
        subthreads = [ ]

        [:min, :max].each { |limit|
          subthreads << Thread.new {
            # Каждый подпоток ищет границу
            # подотчётного ему предела
            search(staff.map(&attribute), input[attribute][limit], limit)
          }
        }

        # Заменяем значения массива подпотоков на результаты
        # полученные по завершению их выполнения.
        subthreads.map!{ |thread| thread.value }

        # Каждый поток возвращает массив состоящий только из тех работников,
        # значение параметра которых удовлетворяют условию поиска.
        staff[subthreads[0], subthreads[1]]
      }
    }

    # Заменив значения массива потоков на результаты полученные по их завершению,
    # и произведя пересечение всех полученных четырёх массивов, вы получаем один
    # результирующий массив, состоящий из только из работников, чьи значения полей
    # удовлетворяет всем условиям поиска.
    result = threads.map!{ |thread| thread.value }.inject(:&)
  }
}

puts "Кол-во экземпляров (кол-во рабочих)"
puts "соответствующих условиям поиска #{result.size}"

# Флэнаган Д., Мацумото Ю., Язык программирования Ruby, 2011, начиная с 446 стр.

# http://ru.wikipedia.org/wiki/%D0%98%D0%BD%D1%82%D0%B5%D1%80%D0%BF%D0%BE%D0%BB%D0%B8%D1%80%D1%83%D1%8E%D1%89%D0%B8%D0%B9_%D0%BF%D0%BE%D0%B8%D1%81%D0%BA
# http://mathhelpplanet.com/static.php?p=javascript-algoritmy-poiska
# http://iguania.ru/algoritmi-programmirovaniya/interpoliruiuschiy-poisk.html

# http://ruby.about.com/od/tasks/f/benchmark.htm