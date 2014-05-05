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

        if limit == :min
          search_min(mid, array, value)
        else
          search_max(mid, array, value)
        end

        # Конец.
        #

        break

      end
    end
  # Если отсутствует минимальное условие
  elsif limit == :min
    mid = 0
  # Если отсутствует максимальное условие
  else
    mid = array.length - 1
  end

  return mid.to_i
end

# Поиск максимального значения индекса в массиве
# соответствующего значению поля поиска
def search_max(mid, array, value)
  length = array.length - 1
  m = mid

  # Если найденный индекс не является последним в массиве
  # не является последним в массиве дубликатов с большей стороны
  if mid != length and array[mid] == array[mid+1]
    min = mid
    max = length

    # Начинаем искать последний дубликат находящийся "справа"
    until array[m] != array[m+1] and array[m] >= array[m-1] and array[m] == array[mid]
      m = (min+max) / 2

      if array[m] != array[mid]
        max = m
      else
        min = m
      end
    end
  end

  # Возвращаем самый крайний индекс
  return m
end

def search_min(mid, array, value)
  length = array.length - 1
  m = mid

  if mid != 0 and array[mid] == array[mid-1]
    min = 0
    max = mid

    until array[m] != array[m-1] and array[m] <= array[m+1] and array[m] == array[mid]
      m = (min+max) / 2

      if array[m] != array[mid]
        min = m
      else
        max = m
      end
    end
  end

  return m
end

result = [ ]

# Массив потоков
threads = [ ]

puts "Всего экземпляров (всего рабочих) #{COUNT}"

Benchmark.bm { |bench|
  bench.report("Весь поиск") {
    # Я почитал про треды. И для меньшего затрачивания времени
    # пременил их, надеюсь вам логика понравится ...
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